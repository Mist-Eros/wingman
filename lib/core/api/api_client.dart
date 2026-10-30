// =============================================================================
// lib/core/api/api_client.dart
//
// OWNER: Lead (lib/core/). Zero-package implementation — only `dart:io` and
// `dart:convert` are used, so nothing here can break because a teammate's
// pubspec is missing a dependency. (flutter_secure_storage lives only in the
// optional `auth/secure_token_store.dart`.)
//
// Responsibilities:
//   • REST  : POST /api/reports, GET /api/tickets, confirm/deny/override,
//             join/vote, health, dev reset.
//   • WSS   : one auto-reconnecting broadcast stream of `ServerEvent`s.
//   • TLS   : trusts the self-signed CA bundled into the app (`assets/certs/
//             ca.crt`), so no phone-side profile is required for the app
//             itself. See docs/certs-and-phones.md.
//
// Everything the feature teams do goes through the instance exposed by
// `CoreScope.apiOf(context)` — never construct an ApiClient inside a feature.
// =============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../incidents/taxonomy.dart';
import '../models/analyze_result.dart';
import '../models/ticket.dart';

/// Server-enforced override window for low-confidence classifications.
const int kOverrideWindowSeconds = 5;

/// Every failure the UI can show comes out as an [ApiException] with an
/// actionable `message` (demo-day rule: no screen may show a bare
/// `SocketException` string to a judge).
class ApiException implements Exception {
  ApiException(
    this.message, {
    this.statusCode,
    this.path,
    this.cause,
  });

  final String message;

  /// null when the request never got an HTTP response (network/TLS/timeout).
  final int? statusCode;
  final String? path;
  final Object? cause;

  bool get isNetworkIssue => statusCode == null;

  @override
  String toString() => 'ApiException(${statusCode ?? 'network'}) $message';
}

/// One decoded WSS message. Ticket events carry [ticket]; connection changes
/// carry [connection]; everything else is still readable via [data] so a
/// newer backend never breaks an older app build.
class ServerEvent {
  const ServerEvent({
    required this.type,
    this.data = const <String, dynamic>{},
    this.ticket,
    this.connection,
    this.detail,
  });

  /// Server → client contract.
  static const String typeHello = 'hello';
  static const String typeTicketCreated = 'ticket.created';
  static const String typeTicketUpdated = 'ticket.updated';
  static const String typeTicketOverrideRequired = 'ticket.override_required';
  static const String typeTicketResolved = 'ticket.resolved';
  static const String typePing = 'ping';
  static const String typeError = 'error';

  /// Client-side synthetic events (never sent by the server).
  static const String typeConnected = 'connection.connected';
  static const String typeDisconnected = 'connection.disconnected';

  final String type;
  final Map<String, dynamic> data;
  final Ticket? ticket;

  /// non-null for [typeConnected] / [typeDisconnected].
  final bool? connection;

  /// Human-readable reason for a disconnect / error event.
  final String? detail;

  bool get isConnectionEvent => connection != null;
  bool get isConnected => connection == true;

  factory ServerEvent.connection(bool connected, {String? detail}) => ServerEvent(
        type: connected ? typeConnected : typeDisconnected,
        connection: connected,
        detail: detail,
      );

  const ServerEvent.ping()
      : type = typePing,
        data = const <String, dynamic>{},
        ticket = null,
        connection = null,
        detail = null;

  @override
  String toString() =>
      'ServerEvent($type${ticket == null ? '' : ', ${ticket!.id}'})';
}

/// Thin REST + WSS client. One instance per app, passed down via `CoreScope`.
class ApiClient {
  ApiClient({
    required String baseUrl,
    String token = '',
    String? caPem,
    this.allowInsecure = false,
    Duration timeout = const Duration(seconds: 15),
  })  : _baseUrl = _normalizeBaseUrl(baseUrl),
        _token = token.trim(),
        _timeout = timeout,
        _securityContext = _buildContext(caPem, allowInsecure);

  final String _baseUrl;
  final String _token;
  final Duration _timeout;

  /// DEV ONLY: accepts any certificate. Enabled with
  /// `--dart-define=DEV_INSECURE=true`. Never for the judged demo if the CA
  /// bundle works — the TLS story is part of the pitch.
  final bool allowInsecure;

  final SecurityContext _securityContext;

  _RealtimeChannel? _channel;
  Stream<ServerEvent>? _events;

  String get baseUrl => _baseUrl;
  bool get hasToken => _token.isNotEmpty;

  /// ws(s)://host:port/ws with the token as a query parameter (the header is
  /// also sent; the server accepts either).
  String get wsUrl {
    final uri = Uri.parse(_baseUrl);
    final scheme = uri.scheme == 'https' ? 'wss' : 'ws';
    final query =
        _token.isEmpty ? '' : '?token=${Uri.encodeQueryComponent(_token)}';
    return '$scheme://${uri.authority}/ws$query';
  }

  Map<String, dynamic> get wsHeaders => <String, dynamic>{
        if (_token.isNotEmpty) HttpHeaders.authorizationHeader: 'Bearer $_token',
      };

  // ── REST ──────────────────────────────────────────────────────────────────

  /// Creates a ticket. Voice flow ships a transcript; menu flow ships
  /// `hintCode` and the server trusts the pick unless `useAi` is true.
  /// NOTE: may take 20-30 s on a cold Ollama model — callers must show a
  /// spinner and keep the button disabled.
  Future<Ticket> report(ReportDraft draft) async {
    final json = await _send(
      'POST',
      '/api/reports',
      body: draft.toJson(),
      timeout: const Duration(seconds: 45),
    );
    return _ticketFrom(json);
  }

  Future<List<Ticket>> listTickets({TicketStatus? status}) async {
    final path = status == null
        ? '/api/tickets'
        : '/api/tickets?status=${Uri.encodeQueryComponent(status.wire)}';
    final json = await _send('GET', path);
    final raw = json['tickets'];
    if (raw is! List) {
      throw ApiException(
        'Malformed /api/tickets response: missing "tickets" list',
        path: path,
      );
    }
    final tickets = <Ticket>[];
    for (final item in raw) {
      if (item is Map<String, dynamic>) {
        try {
          tickets.add(Ticket.fromJson(item));
        } on FormatException catch (error) {
          throw ApiException(
            'Contract mismatch: server sent a ticket this app cannot parse '
            '(${error.message}). Check CONTRACTS.md §5.',
            path: path,
            cause: error,
          );
        }
      }
    }
    return tickets;
  }

  Future<Ticket> getTicket(String ticketId) async {
    final json = await _send('GET', '/api/tickets/$ticketId');
    return _ticketFrom(json);
  }

  Future<Ticket> confirm(
    String ticketId, {
    String? dispatcherId,
    String? dispatcherName,
  }) =>
      _mutate('POST', '/api/tickets/$ticketId/confirm', <String, dynamic>{
        'dispatcher_id': dispatcherId,
        'dispatcher_name': dispatcherName,
      });

  Future<Ticket> deny(
    String ticketId, {
    String? reason,
    String? dispatcherId,
  }) =>
      _mutate('POST', '/api/tickets/$ticketId/deny', <String, dynamic>{
        'reason': reason,
        'dispatcher_id': dispatcherId,
      });

  Future<Ticket> reclassify(
    String ticketId, {
    required String incidentCode,
    Urgency? urgency,
    String? reason,
    String? dispatcherId,
  }) =>
      _mutate('POST', '/api/tickets/$ticketId/override', <String, dynamic>{
        'incident_code': incidentCode,
        'urgency': urgency?.wire,
        'reason': reason,
        'dispatcher_id': dispatcherId,
      });

  Future<Ticket> join(
    String ticketId, {
    required String crewId,
    String? crewName,
  }) =>
      _mutate('POST', '/api/tickets/$ticketId/join', <String, dynamic>{
        'crew_id': crewId,
        'crew_name': crewName,
      });

  Future<Ticket> vote(
    String ticketId, {
    required String crewId,
    bool approve = true,
  }) =>
      _mutate('POST', '/api/tickets/$ticketId/vote', <String, dynamic>{
        'crew_id': crewId,
        'approve': approve,
      });

  Future<Map<String, dynamic>> health() => _send('GET', '/api/health');

  /// One conversational turn of the reporter flow (no ticket is created).
  ///
  /// Show + speak [AnalyzeResult.question], append the user's answer to the
  /// transcript and call again with `clarificationsAsked + 1`. When
  /// [AnalyzeResult.ready] is true, submit with [report].
  Future<AnalyzeResult> analyze(AnalyzeRequest request) async {
    final json = await _send(
      'POST',
      '/api/analyze',
      body: request.toJson(),
      timeout: const Duration(seconds: 45),
    );
    return AnalyzeResult.fromJson(json);
  }

  /// Clears the in-memory store (demo rehearsals). Server may 404 if disabled.
  Future<void> devReset() async {
    await _send('POST', '/api/dev/reset');
  }

  // ── WSS ───────────────────────────────────────────────────────────────────

  /// Broadcast stream: connect once in `main.dart`, keep the subscription for
  /// the app's lifetime (`TicketBoard.start()` does this). If the last listener
  /// cancels, the socket is closed and the stream can be re-listened.
  Stream<ServerEvent> connectEvents() {
    final existing = _events;
    if (existing != null) return existing;
    late final StreamController<ServerEvent> controller;
    controller = StreamController<ServerEvent>.broadcast(
      onListen: () {
        final channel = _channel ??= _RealtimeChannel(this, controller);
        channel.start();
      },
      onCancel: () {
        _channel?.stop();
        _channel = null;
        _events = null;
      },
    );
    _events = controller.stream;
    return _events!;
  }

  /// Closes the WSS channel; REST calls create short-lived clients and need
  /// no cleanup. Call from the root widget's dispose.
  Future<void> close() async {
    final channel = _channel;
    _channel = null;
    _events = null;
    if (channel != null) await channel.stop();
  }

  // ── Internals ─────────────────────────────────────────────────────────────

  Uri _resolve(String path) => Uri.parse('$_baseUrl$path');

  Future<Ticket> _mutate(
    String method,
    String path,
    Map<String, dynamic> body,
  ) async {
    final json = await _send(method, path, body: body);
    return _ticketFrom(json);
  }

  Ticket _ticketFrom(Map<String, dynamic> json) {
    final raw = json['ticket'];
    if (raw is! Map<String, dynamic>) {
      throw ApiException(
        'Malformed response: missing "ticket" object',
        path: '/api',
      );
    }
    try {
      return Ticket.fromJson(raw);
    } on FormatException catch (error) {
      throw ApiException(
        'Contract mismatch: server sent a ticket this app cannot parse '
        '(${error.message}). Check CONTRACTS.md §5.',
        path: '/api',
        cause: error,
      );
    }
  }

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Object? body,
    Duration? timeout,
  }) async {
    final client = newHttpClient();
    final limit = timeout ?? _timeout;
    try {
      final request = await client.openUrl(method, _resolve(path)).timeout(limit);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      if (_token.isNotEmpty) {
        request.headers
            .set(HttpHeaders.authorizationHeader, 'Bearer $_token');
      }
      if (body != null) {
        final payload = utf8.encode(jsonEncode(body));
        request.headers.set(
          HttpHeaders.contentTypeHeader,
          'application/json; charset=utf-8',
        );
        request.contentLength = payload.length;
        request.add(payload);
      }

      final response = await request.close().timeout(limit);
      final text = await utf8.decodeStream(response).timeout(limit);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(
          _serverMessage(text, response.statusCode),
          statusCode: response.statusCode,
          path: path,
        );
      }
      if (text.trim().isEmpty) return const <String, dynamic>{};
      final decoded = jsonDecode(text);
      if (decoded is Map<String, dynamic>) return decoded;
      throw ApiException(
        'Expected a JSON object from $path, got ${decoded.runtimeType}',
        path: path,
      );
    } on ApiException {
      rethrow;
    } on HandshakeException catch (error) {
      throw ApiException(
        'TLS handshake failed for $_baseUrl. The app does not trust the '
        'server certificate: bundle assets/certs/ca.crt and rebuild, or make '
        'sure the server cert contains this exact IP in its SAN '
        '(docs/certs-and-phones.md).',
        cause: error,
        path: path,
      );
    } on SocketException catch (error) {
      throw ApiException(
        'Cannot reach $_baseUrl. Same Wi-Fi? Laptop firewall open on the '
        'port? Backend running? (${error.osError?.message ?? error.message})',
        cause: error,
        path: path,
      );
    } on TimeoutException catch (error) {
      throw ApiException(
        'Request to $path timed out after ${limit.inSeconds}s. If this was a '
        'voice report, the AI model is still loading — try again '
        '(or ask the laptop crew to warm Ollama).',
        cause: error,
        path: path,
      );
    } on FormatException catch (error) {
      throw ApiException(
        'Invalid JSON from $path: ${error.message}',
        cause: error,
        path: path,
      );
    } finally {
      client.close(force: true);
    }
  }

  String _serverMessage(String body, int statusCode) {
    if (body.trim().isEmpty) return 'HTTP $statusCode';
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final detail = decoded['detail'];
        if (detail is String) return 'HTTP $statusCode: $detail';
        if (detail is List && detail.isNotEmpty) {
          return 'HTTP $statusCode: ${detail.first}';
        }
      }
    } on FormatException {
      // fall through to raw body
    }
    return 'HTTP $statusCode: ${body.trim()}';
  }

  /// New short-lived HttpClient bound to the CA bundle. Public so the WSS
  /// channel can reuse it (never share one client between REST calls and a
  /// live socket: `close(force: true)` would kill the socket).
  HttpClient newHttpClient() {
    final client = HttpClient(context: _securityContext);
    client.connectionTimeout = const Duration(seconds: 5);
    client.idleTimeout = const Duration(seconds: 8);
    client.userAgent = 'wingman/1.0';
    if (allowInsecure) {
      client.badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
    }
    return client;
  }

  static String _normalizeBaseUrl(String value) {
    var normalized = value.trim();
    while (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    if (!normalized.startsWith('http://') &&
        !normalized.startsWith('https://')) {
      throw ArgumentError(
        'API base URL must start with http:// or https:// (got "$value")',
      );
    }
    return normalized;
  }

  /// Builds the TLS context used by REST and WSS.
  ///
  /// The self-signed leaf is trusted by pinning the bundled CA. We try PEM
  /// first, then DER (some platforms are picky about the encoding), and as a
  /// last resort fall back to the platform trust store — on iOS/Android that
  /// store only helps if the operator installed the CA profile
  /// (see docs/certs-and-phones.md). Crashing at boot because of a platform
  /// quirk is never acceptable during a demo, so the fallback is intentional.
  static SecurityContext _buildContext(String? caPem, bool allowInsecure) {
    if (caPem == null || caPem.trim().isEmpty) {
      return SecurityContext.defaultContext;
    }
    final text = caPem.trim();
    final der = _pemToDer(text);
    final attempts = <List<int>>[
      utf8.encode(text),
      if (der != null) der,
    ];
    final context = SecurityContext(withTrustedRoots: true);
    for (final bytes in attempts) {
      try {
        context.setTrustedCertificatesBytes(bytes);
        return context;
      } on Object {
        // Try the next encoding.
      }
    }
    // ignore: avoid_print
    print(
      '[tls] could not pin assets/certs/ca.crt on this platform; falling back '
      'to the platform trust store. Install the CA profile on the phone '
      '(docs/certs-and-phones.md).',
    );
    return SecurityContext.defaultContext;
  }

  /// Extracts the first PEM certificate and returns its DER bytes.
  static List<int>? _pemToDer(String pem) {
    final match = RegExp(
      r'-----BEGIN CERTIFICATE-----([\s\S]+?)-----END CERTIFICATE-----',
    ).firstMatch(pem);
    if (match == null) return null;
    final body = match.group(1)!.replaceAll(RegExp(r'\s'), '');
    try {
      return base64Decode(body);
    } on FormatException {
      return null;
    }
  }
}

/// One reconnecting WebSocket. Kept private: feature code listens on
/// [ApiClient.connectEvents] instead.
class _RealtimeChannel {
  _RealtimeChannel(this._api, this._controller);

  final ApiClient _api;
  final StreamController<ServerEvent> _controller;

  WebSocket? _socket;
  HttpClient? _http;
  Timer? _watchdog;
  bool _closed = false;
  bool _running = false;
  int _attempt = 0;
  int _generation = 0;
  DateTime _lastMessageAt = DateTime.now();

  void start() {
    if (_running) return;
    _closed = false;
    _running = true;
    unawaited(_run());
  }

  Future<void> stop() async {
    _closed = true;
    _generation++;
    _running = false;
    _watchdog?.cancel();
    _watchdog = null;
    final socket = _socket;
    _socket = null;
    if (socket != null) {
      try {
        await socket.close(WebSocketStatus.normalClosure);
      } on Object {
        // already dead
      }
    }
    _http?.close(force: true);
    _http = null;
    if (!_controller.isClosed) await _controller.close();
  }

  Future<void> _run() async {
    while (!_closed) {
      final generation = _generation;
      try {
        final http = _http ??= _api.newHttpClient();
        final socket = await WebSocket.connect(
          _api.wsUrl,
          headers: _api.wsHeaders,
          customClient: http,
        ).timeout(const Duration(seconds: 10));

        if (_closed || generation != _generation) {
          await socket.close(WebSocketStatus.normalClosure);
          break;
        }

        _socket = socket;
        _attempt = 0;
        _lastMessageAt = DateTime.now();
        _emit(ServerEvent.connection(true));
        _watchdog = Timer.periodic(const Duration(seconds: 10), (_) {
          if (DateTime.now().difference(_lastMessageAt) >
              const Duration(seconds: 55)) {
            unawaited(_dropSocket());
          }
        });

        final done = Completer<void>();
        socket.listen(
          (dynamic message) {
            _lastMessageAt = DateTime.now();
            _handleMessage(message);
          },
          onError: (Object error, StackTrace stack) {
            // Reconnect loop handles recovery; surface it for the UI banner.
            _emit(ServerEvent.connection(false, detail: error.toString()));
            if (!done.isCompleted) done.complete();
          },
          onDone: () {
            if (!done.isCompleted) done.complete();
          },
          cancelOnError: true,
        );
        await done.future;
      } on Object catch (error) {
        if (_closed) break;
        _emit(ServerEvent.connection(false, detail: error.toString()));
      } finally {
        _watchdog?.cancel();
        _watchdog = null;
        final socket = _socket;
        _socket = null;
        if (socket != null) {
          try {
            await socket.close(WebSocketStatus.normalClosure);
          } on Object {
            // already dead
          }
        }
      }

      if (_closed) break;
      _attempt = _attempt >= 6 ? 6 : _attempt + 1;
      // 1s, 2s, 4s, 8s, then 10s cap. LAN demos recover fast; no jitter needed.
      final seconds = _attempt <= 4 ? (1 << (_attempt - 1)) : 10;
      await Future<void>.delayed(Duration(seconds: seconds));
    }
  }

  Future<void> _dropSocket() async {
    final socket = _socket;
    _socket = null;
    if (socket != null) {
      try {
        await socket.close(WebSocketStatus.goingAway);
      } on Object {
        // already dead
      }
    }
  }

  void _handleMessage(dynamic message) {
    String? text;
    if (message is String) {
      text = message;
    } else if (message is List<int>) {
      text = utf8.decode(message, allowMalformed: true);
    }
    if (text == null) return;

    Map<String, dynamic>? envelope;
    try {
      final decoded = jsonDecode(text);
      if (decoded is Map<String, dynamic>) envelope = decoded;
    } on FormatException {
      return;
    }
    if (envelope == null) return;

    final type = envelope['type'];
    if (type is! String || type.isEmpty) return;
    if (type == ServerEvent.typePing) {
      _lastMessageAt = DateTime.now();
      return;
    }

    final rawData = envelope['data'];
    final data = rawData is Map<String, dynamic>
        ? rawData
        : const <String, dynamic>{};

    Ticket? ticket;
    final rawTicket = data['ticket'];
    if (rawTicket is Map<String, dynamic>) {
      try {
        ticket = Ticket.fromJson(rawTicket);
      } on Object catch (error) {
        // Never kill the live feed because one payload is bad.
        // ignore: avoid_print
        print('[ws] dropped malformed ticket in "$type": $error');
        return;
      }
    }
    _emit(ServerEvent(type: type, data: data, ticket: ticket));
  }

  void _emit(ServerEvent event) {
    if (!_controller.isClosed) _controller.add(event);
  }
}
