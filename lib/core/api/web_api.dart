// =============================================================================
// lib/core/api/web_api.dart
//
// Small web-safe client for the desktop dashboard. The phone app uses ApiClient
// (dart:io + pinned TLS); browsers don't have dart:io, so the dashboard uses
// package:http + web_socket_channel. Same REST/WSS contract, no TLS pinning
// (the demo dashboard runs against the plain-HTTP fallback backend).
//
// The dashboard is a READ + quick-act surface for the laptop screen.
// =============================================================================

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/ticket.dart';

class WebApiException implements Exception {
  WebApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

class WebApi {
  WebApi({required this.baseUrl, required this.token});

  final String baseUrl;
  final String token;

  Map<String, String> get _headers => <String, String>{
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };

  Future<List<Ticket>> listTickets() async {
    final response = await http
        .get(Uri.parse('$baseUrl/api/tickets'), headers: _headers)
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw WebApiException('HTTP ${response.statusCode} la /api/tickets');
    }
    final body =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final rawTickets = body['tickets'] as List<dynamic>? ?? const <dynamic>[];
    return <Ticket>[
      for (final raw in rawTickets)
        if (raw is Map<String, dynamic>) Ticket.fromJson(raw),
    ];
  }

  Future<Ticket> _post(String path, Map<String, dynamic> payload) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl$path'),
          headers: _headers,
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 15));
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode >= 400) {
      final detail = body is Map<String, dynamic> ? body['detail'] : body;
      throw WebApiException('HTTP ${response.statusCode}: $detail');
    }
    final ticket = (body as Map<String, dynamic>)['ticket'];
    if (ticket is! Map<String, dynamic>) {
      throw WebApiException('Răspuns fără tichet');
    }
    return Ticket.fromJson(ticket);
  }

  Future<Ticket> confirm(String id) => _post(
        '/api/tickets/$id/confirm',
        <String, dynamic>{
          'dispatcher_id': 'admin-web',
          'dispatcher_name': 'Andy Admin',
        },
      );

  Future<Ticket> deny(String id, {String? reason}) => _post(
        '/api/tickets/$id/deny',
        <String, dynamic>{
          'dispatcher_id': 'admin-web',
          'dispatcher_name': 'Andy Admin',
          'reason': reason,
        },
      );

  Future<Ticket> reclassify(String id, String incidentCode) => _post(
        '/api/tickets/$id/override',
        <String, dynamic>{
          'incident_code': incidentCode,
          'dispatcher_id': 'admin-web',
          'dispatcher_name': 'Andy Admin',
        },
      );

  /// WSS stream of raw envelopes (`{"type": "...", "ticket": {...}}`).
  Stream<Map<String, dynamic>> events() {
    final wsBase = baseUrl
        .replaceFirst('https://', 'wss://')
        .replaceFirst('http://', 'ws://');
    final channel = WebSocketChannel.connect(
      Uri.parse('$wsBase/ws?token=$token'),
    );
    return channel.stream
        .map((message) => jsonDecode(message as String))
        .where((decoded) => decoded is Map<String, dynamic>)
        .cast<Map<String, dynamic>>();
  }
}
