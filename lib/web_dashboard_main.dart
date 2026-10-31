// =============================================================================
// lib/web_dashboard_main.dart
//
// Desktop control room for the demo (runs in Edge, no Visual Studio needed):
//   flutter build web --release -t lib/web_dashboard_main.dart \
//     --dart-define=API_BASE=http://<laptop-ip>:8080 --dart-define=API_TOKEN=demo-token
// then serve build/web and open http://127.0.0.1:8090/
//
// It is a real-time watch surface over the SAME backend the phones use:
// WSS events + REST actions (confirm / deny / reclassify). Phones stay on the
// TLS listener; this dashboard uses the plain-HTTP demo fallback backend.
// =============================================================================

import 'dart:async';

import 'package:flutter/material.dart';

import 'core/api/web_api.dart';
import 'core/incidents/taxonomy.dart';
import 'core/models/ticket.dart';

const String _kBase = String.fromEnvironment(
  'API_BASE',
  defaultValue: 'http://192.168.0.170:8080',
);
const String _kToken = String.fromEnvironment(
  'API_TOKEN',
  defaultValue: 'demo-token',
);

void main() {
  runApp(const DashboardApp());
}

// ── dark "ops" palette ───────────────────────────────────────────────────────
abstract final class Ops {
  static const Color bg = Color(0xFF081120);
  static const Color panel = Color(0xFF0E1A2B);
  static const Color card = Color(0xFF132238);
  static const Color line = Color(0xFF22324A);
  static const Color ink = Color(0xFFE8F0FA);
  static const Color muted = Color(0xFF8FA3BD);
  static const Color accent = Color(0xFF5BA7FF);
  static const Color green = Color(0xFF3DD68C);
  static const Color red = Color(0xFFFF6B6B);
  static const Color orange = Color(0xFFFFA94D);
  static const Color yellow = Color(0xFFFFD43B);

  static Color urgency(Urgency urgency) => switch (urgency) {
        Urgency.critical => red,
        Urgency.high => orange,
        Urgency.medium => yellow,
        Urgency.low => green,
      };

  static Color status(TicketStatus status) => switch (status) {
        TicketStatus.pendingOverride => orange,
        TicketStatus.dispatched => accent,
        TicketStatus.inProgress => yellow,
        TicketStatus.resolved => green,
        TicketStatus.denied => muted,
      };
}

class DashboardApp extends StatelessWidget {
  const DashboardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wingman · Control Room',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Ops.bg,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Ops.accent,
          brightness: Brightness.dark,
          surface: Ops.panel,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Ops.bg,
          surfaceTintColor: Colors.transparent,
          foregroundColor: Ops.ink,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          color: Ops.card,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: Ops.line),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: Ops.accent,
            foregroundColor: const Color(0xFF061A30),
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        snackBarTheme: const SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Ops.card,
          contentTextStyle: TextStyle(color: Ops.ink),
        ),
      ),
      home: const ControlRoom(),
    );
  }
}

class ControlRoom extends StatefulWidget {
  const ControlRoom({super.key});

  @override
  State<ControlRoom> createState() => _ControlRoomState();
}

class _ControlRoomState extends State<ControlRoom> {
  final WebApi _api = WebApi(baseUrl: _kBase, token: _kToken);
  final Map<String, Ticket> _tickets = <String, Ticket>{};
  StreamSubscription<Map<String, dynamic>>? _subscription;
  Timer? _reconnectTimer;
  Timer? _refreshTimer;
  bool _connected = false;
  bool _loading = true;
  bool _onlyActive = true;
  String? _error;
  String _lastEvent = 'Aștept evenimente live…';
  String? _selectedId;

  @override
  void initState() {
    super.initState();
    _bootstrap();
    _refreshTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (!_loading) _load(silent: true);
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _reconnectTimer?.cancel();
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    await _load();
    _connect();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final tickets = await _api.listTickets();
      if (!mounted) return;
      setState(() {
        _tickets
          ..clear()
          ..addEntries(tickets.map((t) => MapEntry(t.id, t)));
        _error = null;
        _loading = false;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _error = '$error';
        _loading = false;
      });
    }
  }

  void _connect() {
    _subscription?.cancel();
    try {
      _subscription = _api.events().listen(
        _onEvent,
        onError: (Object error) {
          if (!mounted) return;
          setState(() {
            _connected = false;
            _error = 'WSS: $error';
          });
          _scheduleReconnect();
        },
        onDone: () {
          if (!mounted) return;
          setState(() => _connected = false);
          _scheduleReconnect();
        },
      );
      setState(() {
        _connected = true;
        _error = null;
      });
    } on Object catch (error) {
      setState(() {
        _connected = false;
        _error = 'WSS: $error';
      });
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      _load(silent: true);
      _connect();
    });
  }

  void _onEvent(Map<String, dynamic> event) {
    final type = event['type'] as String? ?? '';
    final raw = event['ticket'];
    if (raw is Map<String, dynamic>) {
      final ticket = Ticket.fromJson(raw);
      setState(() {
        _tickets[ticket.id] = ticket;
        _lastEvent =
            '${_eventLabel(type)} · ${ticket.incidentCode} · ${ticket.status.labelRo}';
        _error = null;
      });
      return;
    }
    if (type == 'hello') {
      setState(() {
        _connected = true;
        _lastEvent = 'Conectat la fluxul live';
      });
    }
  }

  String _eventLabel(String type) => switch (type) {
        'ticket.created' => 'Tichet nou',
        'ticket.updated' => 'Actualizare',
        'ticket.override_required' => 'Necesită confirmare',
        'ticket.resolved' => 'Rezolvat',
        _ => 'Eveniment',
      };

  Ticket? get _selected => _selectedId == null ? null : _tickets[_selectedId];

  List<Ticket> get _visibleTickets {
    final all = _tickets.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (!_onlyActive) return all;
    return all
        .where((t) =>
            t.status == TicketStatus.pendingOverride ||
            t.status == TicketStatus.dispatched ||
            t.status == TicketStatus.inProgress)
        .toList();
  }

  int _count(Urgency urgency) =>
      _visibleTickets.where((t) => t.urgency == urgency).length;

  Future<void> _confirm(Ticket ticket) async {
    try {
      final updated = await _api.confirm(ticket.id);
      setState(() => _tickets[updated.id] = updated);
    } on Object catch (error) {
      _toast('Confirmarea a eșuat: $error');
    }
  }

  Future<void> _deny(Ticket ticket) async {
    try {
      final updated = await _api.deny(ticket.id, reason: 'fals pozitiv');
      setState(() => _tickets[updated.id] = updated);
    } on Object catch (error) {
      _toast('Respingerea a eșuat: $error');
    }
  }

  Future<void> _reclassify(Ticket ticket) async {
    final code = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        backgroundColor: Ops.panel,
        title: const Text('Reclasifică incidentul'),
        children: <Widget>[
          SizedBox(
            width: 420,
            height: 420,
            child: ListView(
              children: <Widget>[
                for (final type in IncidentTaxonomy.all)
                  ListTile(
                    dense: true,
                    title: Text('${type.code} · ${type.labelRo}',
                        style: const TextStyle(color: Ops.ink)),
                    subtitle: Text(
                      type.urgency.labelRo,
                      style: TextStyle(color: Ops.urgency(type.urgency)),
                    ),
                    onTap: () => Navigator.of(context).pop(type.code),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
    if (code == null || !mounted) return;
    try {
      final updated = await _api.reclassify(ticket.id, code);
      setState(() => _tickets[updated.id] = updated);
    } on Object catch (error) {
      _toast('Reclasificarea a eșuat: $error');
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              SizedBox(width: 290, child: _sidebar()),
              const SizedBox(width: 14),
              Expanded(child: _feed()),
              const SizedBox(width: 14),
              SizedBox(width: 400, child: _detail()),
            ],
          ),
        ),
      ),
    );
  }

  // ── sidebar ────────────────────────────────────────────────────────────────
  Widget _sidebar() {
    final all = _tickets.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: Ops.accent.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Ops.accent.withValues(alpha: 0.5)),
              ),
              child:
                  const Icon(Icons.flight_takeoff_rounded, color: Ops.accent),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Wingman',
                      style: TextStyle(
                          color: Ops.ink,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5)),
                  Text('CONTROL ROOM · live',
                      style: TextStyle(
                          color: Ops.muted, fontSize: 10, letterSpacing: 1.2)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _connectionPill(),
        const SizedBox(height: 16),
        _panel(
          title: 'Urgență (coadă activă)',
          child: Column(
            children: <Widget>[
              _statRow('Critică', _count(Urgency.critical), Ops.red),
              _statRow('Ridicată', _count(Urgency.high), Ops.orange),
              _statRow('Medie', _count(Urgency.medium), Ops.yellow),
              _statRow('Scăzută', _count(Urgency.low), Ops.green),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _panel(
          title: 'Server',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Tichete: $all', style: const TextStyle(color: Ops.ink)),
              const SizedBox(height: 4),
              Text('API: $_kBase',
                  style: const TextStyle(color: Ops.muted, fontSize: 11)),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _load(),
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Reîncarcă'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Ops.ink,
                    side: const BorderSide(color: Ops.line),
                  ),
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        _panel(
          title: 'Ultimul eveniment',
          child: Text(_lastEvent,
              style: const TextStyle(color: Ops.ink, fontSize: 12)),
        ),
        const SizedBox(height: 10),
        const Text(
          'Demo local · WSS live · fără cloud',
          style: TextStyle(color: Ops.muted, fontSize: 10),
        ),
      ],
    );
  }

  Widget _connectionPill() {
    final color = _connected ? Ops.green : Ops.red;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.circle, size: 9, color: color),
          const SizedBox(width: 8),
          Text(
            _connected ? 'WSS conectat' : 'WSS deconectat',
            style: TextStyle(
                color: color, fontWeight: FontWeight.w700, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _panel({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Ops.panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Ops.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(title.toUpperCase(),
              style: const TextStyle(
                  color: Ops.muted, fontSize: 10, letterSpacing: 1.1)),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _statRow(String label, int value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: <Widget>[
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
              child: Text(label, style: const TextStyle(color: Ops.muted))),
          Text('$value',
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w800, fontSize: 16)),
        ],
      ),
    );
  }

  // ── feed ───────────────────────────────────────────────────────────────────
  Widget _feed() {
    final tickets = _visibleTickets;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            const Text('Coadă incidente',
                style: TextStyle(
                    color: Ops.ink, fontSize: 24, fontWeight: FontWeight.w800)),
            const SizedBox(width: 10),
            _badge('${tickets.length}', Ops.accent),
            const Spacer(),
            FilterChip(
              label: Text(_onlyActive ? 'Doar active' : 'Toate'),
              selected: _onlyActive,
              onSelected: (value) => setState(() => _onlyActive = value),
              selectedColor: Ops.accent.withValues(alpha: 0.2),
              checkmarkColor: Ops.accent,
              labelStyle: const TextStyle(color: Ops.ink, fontSize: 12),
              side: const BorderSide(color: Ops.line),
              backgroundColor: Ops.panel,
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_error != null)
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Ops.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Ops.red.withValues(alpha: 0.4)),
            ),
            child: Text(_error!,
                style: const TextStyle(color: Ops.red, fontSize: 12)),
          ),
        if (_error != null) const SizedBox(height: 10),
        Expanded(
          child: _loading && _tickets.isEmpty
              ? const Center(
                  child: CircularProgressIndicator(color: Ops.accent))
              : tickets.isEmpty
                  ? _emptyFeed()
                  : ListView.separated(
                      itemCount: tickets.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) =>
                          _ticketCard(tickets[index]),
                    ),
        ),
      ],
    );
  }

  Widget _emptyFeed() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const <Widget>[
            Icon(Icons.flight_land_rounded, color: Ops.muted, size: 56),
            SizedBox(height: 10),
            Text('Niciun incident activ', style: TextStyle(color: Ops.ink)),
            SizedBox(height: 4),
            Text('Pornește un raport din aplicația de pe telefon.',
                style: TextStyle(color: Ops.muted, fontSize: 12)),
          ],
        ),
      );

  Widget _ticketCard(Ticket ticket) {
    final selected = ticket.id == _selectedId;
    final urgencyColor = Ops.urgency(ticket.urgency);
    return Material(
      color: Ops.card,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () => setState(() => _selectedId = ticket.id),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? Ops.accent : Ops.line,
              width: selected ? 1.6 : 1,
            ),
          ),
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 4,
                height: 84,
                decoration: BoxDecoration(
                  color: urgencyColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        _badge(ticket.incidentCode, urgencyColor),
                        const SizedBox(width: 8),
                        _badge(ticket.urgency.labelRo, urgencyColor),
                        const SizedBox(width: 8),
                        _badge(
                            ticket.status.labelRo, Ops.status(ticket.status)),
                        const Spacer(),
                        Text(
                          '${ticket.confidence.toStringAsFixed(2)} · ${_ago(ticket.createdAt)}',
                          style:
                              const TextStyle(color: Ops.muted, fontSize: 11),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(ticket.labelRo,
                        style: const TextStyle(
                            color: Ops.ink,
                            fontSize: 16,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(
                      '${ticket.location.display.isEmpty ? 'Locație nespecificată' : ticket.location.display} · ${ticket.departmentsLabel}',
                      style: const TextStyle(color: Ops.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detail() {
    final ticket = _selected;
    if (ticket == null) {
      return Container(
        decoration: BoxDecoration(
          color: Ops.panel,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Ops.line),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.radar_rounded, color: Ops.muted, size: 48),
              SizedBox(height: 10),
              Text('Selectează un incident',
                  style:
                      TextStyle(color: Ops.ink, fontWeight: FontWeight.w600)),
              SizedBox(height: 4),
              Text('Detaliile și acțiunile apar aici.',
                  style: TextStyle(color: Ops.muted, fontSize: 12)),
            ],
          ),
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: Ops.panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Ops.line),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(ticket.incidentCode,
                    style: TextStyle(
                        color: Ops.urgency(ticket.urgency),
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        letterSpacing: 0.4)),
              ),
              IconButton(
                onPressed: () => setState(() => _selectedId = null),
                icon: const Icon(Icons.close_rounded, color: Ops.muted),
              ),
            ],
          ),
          Text(ticket.labelRo,
              style: const TextStyle(
                  color: Ops.ink, fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _badge('Urgență: ${ticket.urgency.labelRo}',
                  Ops.urgency(ticket.urgency)),
              _badge(
                  'Stare: ${ticket.status.labelRo}', Ops.status(ticket.status)),
              _badge('Probabilitate Craiova ${ticket.likelihoodLabel}',
                  Ops.accent),
            ],
          ),
          const SizedBox(height: 14),
          _kv('Locație',
              ticket.location.display.isEmpty ? '—' : ticket.location.display),
          _kv('Departamente', ticket.departmentsLabel),
          _kv('Raportat de', ticket.reporterName),
          _kv('Sursă', ticket.source.labelRo),
          _kv('AI', ticket.aiSource.labelRo),
          _kv('Transcriere', ticket.transcript),
          if ((ticket.aiRationale ?? '').isNotEmpty)
            _kv('Raționament AI', ticket.aiRationale!),
          if (ticket.resolutionNote != null &&
              ticket.resolutionNote!.isNotEmpty)
            _kv('Notă rezolvare', ticket.resolutionNote!),
          const SizedBox(height: 16),
          if (ticket.status == TicketStatus.pendingOverride) ...<Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _confirm(ticket),
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Confirmă'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _deny(ticket),
                    icon: const Icon(Icons.close_rounded),
                    label: const Text('Respinge'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Ops.red,
                      side: BorderSide(color: Ops.red.withValues(alpha: 0.6)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          if (ticket.status == TicketStatus.dispatched ||
              ticket.status == TicketStatus.inProgress) ...<Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _reclassify(ticket),
                    icon: const Icon(Icons.swap_horiz_rounded),
                    label: const Text('Reclasifică'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Ops.ink,
                      side: const BorderSide(color: Ops.line),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _deny(ticket),
                    icon: const Icon(Icons.block_rounded),
                    label: const Text('Respinge'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Ops.red,
                      side: BorderSide(color: Ops.red.withValues(alpha: 0.6)),
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (ticket.status == TicketStatus.resolved)
            const Row(
              children: <Widget>[
                Icon(Icons.task_alt_rounded, color: Ops.green),
                SizedBox(width: 8),
                Text('Rezolvat', style: TextStyle(color: Ops.green)),
              ],
            ),
        ],
      ),
    );
  }

  Widget _kv(String key, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(key.toUpperCase(),
                style: const TextStyle(
                    color: Ops.muted, fontSize: 9, letterSpacing: 1.1)),
            const SizedBox(height: 3),
            Text(value, style: const TextStyle(color: Ops.ink, fontSize: 13)),
          ],
        ),
      );

  Widget _badge(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.55)),
        ),
        child: Text(text,
            style: TextStyle(
                color: color, fontSize: 11, fontWeight: FontWeight.w700)),
      );

  String _ago(DateTime time) {
    final delta = DateTime.now().difference(time.toLocal());
    if (delta.inMinutes < 1) return 'acum ${delta.inSeconds}s';
    if (delta.inHours < 1) return 'acum ${delta.inMinutes}m';
    return 'acum ${delta.inHours}h';
  }
}
