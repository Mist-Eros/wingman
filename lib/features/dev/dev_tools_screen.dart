// =============================================================================
// lib/features/dev/dev_tools_screen.dart
//
// Demo/Debug surface for the Lead + judges' Q&A:
//   • preview every time-of-day sky look without changing the clock;
//   • see live backend health (AI, STT, WSS, tickets);
//   • trigger demo actions (reset store, simulate a report);
//   • see the hardcoded demo accounts and their department scopes.
//
// Reached from the login screen (wrench icon). Dev-only, no product logic here.
// =============================================================================

import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/auth/demo_accounts.dart';
import '../../core/core_scope.dart';
import '../../core/models/ticket.dart';
import '../../core/theme/wingman_theme.dart';
import '../../core/widgets/sky_background.dart';

class DevToolsScreen extends StatefulWidget {
  const DevToolsScreen({super.key});

  @override
  State<DevToolsScreen> createState() => _DevToolsScreenState();
}

class _DevToolsScreenState extends State<DevToolsScreen> {
  SkyPeriod _period = SkyPeriod.current();
  Map<String, dynamic>? _health;
  bool _loadingHealth = false;
  bool _busy = false;
  String _lastAction = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_health == null) _refreshHealth();
  }

  ApiClient get _api => CoreScope.apiOf(context);

  Future<void> _refreshHealth() async {
    setState(() => _loadingHealth = true);
    try {
      final health = await _api.health();
      if (!mounted) return;
      setState(() {
        _health = health;
        _loadingHealth = false;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingHealth = false;
        _lastAction = 'Health eșuat: $error';
      });
    }
  }

  Future<void> _resetDemo() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Resetezi demo-ul?'),
        content: const Text(
          'Readuce cele 5 cazuri pregătite, golește istoricul și '
          'resetează punctele tuturor conturilor. Acțiunea este definitivă.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Anulează'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Resetează'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _resetStore();
  }

  Future<void> _resetStore() async {
    if (!mounted) return;
    final reset = CoreScope.of(context).demoReset;
    setState(() => _busy = true);
    try {
      final result = await reset.resetPrepared();
      if (!mounted) return;
      setState(() {
        _busy = false;
        _lastAction =
            'Demo resetat: ${result.tickets} tichete (${result.local ? 'local' : 'live'}).';
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _lastAction = 'Reset eșuat: $error';
      });
    }
  }

  Future<void> _simulateReport() async {
    setState(() => _busy = true);
    try {
      final ticket = await _api.report(
        const ReportDraft(
          source: ReportSource.voice,
          transcript:
              'Ceva nu este în regulă pe hol, nu îmi dau seama exact ce.',
          reporterId: 'dev-tools',
          reporterName: 'Dev Tools',
        ),
      );
      await CoreScope.boardOf(context).refresh();
      if (!mounted) return;
      setState(() {
        _busy = false;
        _lastAction =
            'Tichet ${ticket.incidentCode} creat (${ticket.status.wire}, '
            'confidence ${ticket.confidence.toStringAsFixed(2)}). '
            'Verifică dispecerul / control room-ul.';
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _lastAction = 'Simulare eșuată: $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final board = CoreScope.boardOf(context);
    final theme = Theme.of(context);
    final kBase = _api.baseUrl;

    return Scaffold(
      backgroundColor: WingmanColors.background,
      appBar: AppBar(
        title: const Text('DevTools · Wingman'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Reîncarcă health',
            onPressed: _refreshHealth,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          WingmanSpacing.page,
          WingmanSpacing.md,
          WingmanSpacing.page,
          WingmanSpacing.xxl,
        ),
        children: <Widget>[
          // ── local/live mode ───────────────────────────────────────────────
          _SectionCard(
            title: 'Mod date · Local / Live',
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: board.isLocalDemo,
              onChanged: CoreScope.of(context).onLocalModeChanged == null
                  ? null
                  : (value) => CoreScope.of(context).onLocalModeChanged!(value),
              title: Text(
                board.isLocalDemo
                    ? 'Demo local · instant'
                    : 'Live · REST + WSS',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                board.isLocalDemo
                    ? 'Fără server, fără adb reverse. Datele se resetează la '
                        'schimbarea modului sau la repornirea aplicației.'
                    : 'Vorbește cu backendul/SQLite și control room-ul. '
                        'Necesită cablu/adb reverse stabil.',
              ),
            ),
          ),
          const SizedBox(height: WingmanSpacing.lg),

          // ── sky preview ───────────────────────────────────────────────────
          ClipRRect(
            borderRadius: WingmanRadius.card,
            child: SizedBox(
              height: 230,
              child: SkyBackground(
                period: _period,
                showGround: true,
                child: Padding(
                  padding: const EdgeInsets.all(WingmanSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          const Icon(Icons.flight_takeoff_rounded,
                              color: Colors.white, size: 28),
                          const SizedBox(width: 8),
                          const Text(
                            'Wingman',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              _period.labelRo,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      const Text(
                        'Previzualizare aspect',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: WingmanSpacing.lg),

          // ── period selector ───────────────────────────────────────────────
          Text('Aspect după ora zilei',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            'Acum: ${SkyPeriod.current().labelRo} '
            '(${TimeOfDay.now().hour.toString().padLeft(2, '0')}:'
            '${TimeOfDay.now().minute.toString().padLeft(2, '0')}). '
            'Aplicația alege automat; aici poți forța pentru poze/date locale. '
            'Build determinist: --dart-define=SKY_PERIOD=night',
            style:
                theme.textTheme.bodySmall?.copyWith(color: WingmanColors.muted),
          ),
          const SizedBox(height: WingmanSpacing.md),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final period in SkyPeriod.values)
                ChoiceChip(
                  label: Text(period.labelRo),
                  selected: _period == period,
                  onSelected: (_) => setState(() => _period = period),
                  selectedColor: WingmanColors.navy,
                  labelStyle: TextStyle(
                    color: _period == period ? Colors.white : WingmanColors.ink,
                    fontWeight: FontWeight.w600,
                  ),
                  side: const BorderSide(color: WingmanColors.line),
                  backgroundColor: Colors.white,
                ),
            ],
          ),
          const SizedBox(height: WingmanSpacing.md),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: () => setState(() {
                _period = SkyPeriod
                    .values[(_period.index + 1) % SkyPeriod.values.length];
              }),
              icon: const Icon(Icons.autorenew_rounded),
              label: Text('Ciclu aspect · acum ${_period.labelRo}'),
            ),
          ),
          const SizedBox(height: WingmanSpacing.xl),

          // ── server / health ───────────────────────────────────────────────
          _SectionCard(
            title: 'Server',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _kv('API', kBase),
                _kv('WSS', board.connected ? 'conectat' : 'deconectat'),
                _kv('Tichete', '${board.tickets.length}'),
                _kv(
                  'Ollama',
                  _health == null
                      ? (_loadingHealth ? 'se verifică…' : '—')
                      : '${_health!['ollama']?['last_ok'] == true ? 'răspunde' : 'indisponibil'} '
                          '(${_health!['ollama']?['model'] ?? '?'})',
                ),
                _kv(
                  'STT',
                  _health == null
                      ? '—'
                      : '${_health!['stt']?['available'] == true ? 'disponibil' : 'indisponibil'} '
                          '(${_health!['stt']?['model'] ?? '?'})',
                ),
                _kv('Quorum echipaj', '1 / departament implicat'),
              ],
            ),
          ),
          const SizedBox(height: WingmanSpacing.md),

          // ── demo actions ──────────────────────────────────────────────────
          _SectionCard(
            title: 'Acțiuni locale',
            child: Column(
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _busy ? null : _simulateReport,
                        icon: const Icon(Icons.add_alert_rounded),
                        label: const Text('Simulează raport'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (CoreScope.domainOf(context).features.demoReset)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _busy ? null : _resetDemo,
                          icon: const Icon(Icons.restart_alt_rounded),
                          label: const Text('Reset demo · 5 cazuri'),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(WingmanSpacing.md),
                  decoration: BoxDecoration(
                    color: WingmanColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(WingmanRadius.sm),
                  ),
                  child: const Text(
                    'Scenă completă pentru repetiție (rulează în terminal):\n'
                    'python backend\\seed_demo.py --reset',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: WingmanColors.muted,
                    ),
                  ),
                ),
                if (_lastAction.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 8),
                  Text(
                    _lastAction,
                    style: const TextStyle(
                      color: WingmanColors.navy,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: WingmanSpacing.md),

          // ── accounts ──────────────────────────────────────────────────────
          _SectionCard(
            title: 'Conturi & scop',
            child: Column(
              children: <Widget>[
                for (final account in demoAccounts)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: <Widget>[
                        SizedBox(
                          width: 92,
                          child: Text(
                            '@${account.username}',
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              color: WingmanColors.ink,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: WingmanColors.surfaceMuted,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            account.tag,
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: WingmanColors.navy,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            account.toSession().scopeLabel,
                            style: const TextStyle(
                              fontSize: 11,
                              color: WingmanColors.muted,
                            ),
                          ),
                        ),
                        Text(
                          account.passwordHint,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 10,
                            color: WingmanColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: WingmanSpacing.md),
          Text(
            'Control room (desktop): rulează scripts\\serve_dashboard.ps1 '
            '(Waterfox) sau deschide http://127.0.0.1:8090/',
            style:
                theme.textTheme.bodySmall?.copyWith(color: WingmanColors.muted),
          ),
        ],
      ),
    );
  }

  Widget _kv(String key, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SizedBox(
              width: 132,
              child: Text(key,
                  style: const TextStyle(
                      fontSize: 11,
                      letterSpacing: 0.6,
                      color: WingmanColors.muted)),
            ),
            Expanded(
              child: Text(value,
                  style: const TextStyle(
                      fontSize: 12,
                      color: WingmanColors.ink,
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(WingmanSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: WingmanColors.navy,
              ),
            ),
            const SizedBox(height: WingmanSpacing.md),
            child,
          ],
        ),
      ),
    );
  }
}
