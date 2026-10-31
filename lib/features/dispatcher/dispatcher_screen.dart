// =============================================================================
// OWNER: Fita Redu Mihai (lib/features/dispatcher/).
//
// Frozen contract for main.dart:
//   • class name: DispatcherScreen
//   • const constructor, no required arguments
//   • deps via CoreScope.sessionOf / boardOf
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/core_scope.dart';
import '../../core/incidents/taxonomy.dart';
import '../../core/models/session.dart';
import '../../core/models/ticket.dart';
import '../../core/state/ticket_board.dart';
import '../../core/widgets/report_action_bar.dart';
import '../../core/widgets/reporter_count_chip.dart';
import '../../core/widgets/ticket_media_panel.dart';
import '../rewards/account_screen.dart';
import '../reporter/reporter_screen.dart';
import 'animated_ticket_item.dart';
import 'demo_tickets.dart';
import 'department_queue_strip.dart';
import 'dispatcher_density.dart';
import 'dispatcher_dialogs.dart';
import 'dispatcher_filters.dart';
import 'dispatcher_history.dart';
import 'override_countdown_card.dart';
import 'ticket_feed_card.dart';
import 'ticket_timeline.dart';
import 'stats_pane.dart';
import 'urgency_style.dart';
import 'zone_board.dart';

class DispatcherScreen extends StatefulWidget {
  const DispatcherScreen({super.key});

  @override
  State<DispatcherScreen> createState() => _DispatcherScreenState();
}

class _DispatcherScreenState extends State<DispatcherScreen>
    with SingleTickerProviderStateMixin {
  DispatcherFilters _filters = const DispatcherFilters();
  String? _selectedTicketId;
  final Set<String> _busyIds = <String>{};
  final FocusNode _focusNode = FocusNode();

  // Live by default: when the server has tickets the dispatcher shows them.
  // Demo mode is an explicit toggle (used for the stage scene when the laptop
  // is not on the same network as the phones).
  bool _forceDemo = false;
  late List<Ticket> _demoTickets;
  DispatcherDensity _density = DispatcherDensity.comfortable;
  _AdminTab _adminTab = _AdminTab.queue;

  final List<DispatcherHistoryEntry> _history = <DispatcherHistoryEntry>[];
  String _lastEventLabel = 'Niciun eveniment încă';
  List<Ticket> _prevLiveSnapshot = const <Ticket>[];
  Set<String> _knownPendingIds = <String>{};
  bool _pendingFlash = false;
  bool _offeredLiveSwitch = false;

  late final AnimationController _flashController;
  TicketBoard? _board;
  bool _boardListening = false;

  @override
  void initState() {
    super.initState();
    _demoTickets = buildDemoTickets();
    _knownPendingIds =
        _demoTickets.where((t) => t.isPendingOverride).map((t) => t.id).toSet();
    _flashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final board = CoreScope.boardOf(context);
    if (!identical(board, _board)) {
      _board?.removeListener(_onBoardChanged);
      _board = board;
      _board!.addListener(_onBoardChanged);
      _boardListening = true;
      _prevLiveSnapshot = List<Ticket>.of(board.tickets);
    }
  }

  void _onBoardChanged() {
    final board = _board;
    if (board == null || !mounted) return;
    _watchPendingAndLive(board);
  }

  @override
  void dispose() {
    if (_boardListening) {
      _board?.removeListener(_onBoardChanged);
    }
    _flashController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  bool _usingDemo(TicketBoard board) => _forceDemo || board.isEmpty;

  List<Ticket> _sourceTickets(TicketBoard board) =>
      (_usingDemo(board) ? _demoTickets : board.tickets)
          .where((t) => !t.status.isTerminal)
          .toList(growable: false);

  // The 5-second dispatcher override window was removed: nothing waits for a
  // human decision, so the pending list is always empty.
  List<Ticket> _pending(TicketBoard board) => const <Ticket>[];

  List<Ticket> _feed(TicketBoard board) {
    if (_usingDemo(board)) {
      return _filters.applyToList(_sourceTickets(board), excludePending: true);
    }
    return _filters.apply(board, excludePending: true);
  }

  Ticket? _findTicket(TicketBoard board, String? id) {
    if (id == null) return null;
    if (_usingDemo(board)) {
      for (final t in _demoTickets) {
        if (t.id == id) return t;
      }
      return null;
    }
    return board.find(id);
  }

  void _pushHistory(DispatcherHistoryEntry entry) {
    setState(() {
      _history.insert(0, entry);
      if (_history.length > 40) {
        _history.removeRange(40, _history.length);
      }
      _lastEventLabel = entry.summary;
    });
  }

  void _reloadDemo() {
    setState(() {
      _demoTickets = buildDemoTickets();
      _selectedTicketId = null;
      _knownPendingIds = _demoTickets
          .where((t) => t.isPendingOverride)
          .map((t) => t.id)
          .toSet();
      _forceDemo = true;
    });
    _pushHistory(
      DispatcherHistoryEntry(
        at: DateTime.now().toUtc(),
        kind: DispatcherHistoryKind.observed,
        ticketId: 'demo',
        summary: 'Scenă demo reîncărcată (${_demoTickets.length} tichete)',
      ),
    );
    _triggerPendingAlert(force: true);
  }

  void _patchDemo(String ticketId, Ticket Function(Ticket) update) {
    setState(() {
      _demoTickets = <Ticket>[
        for (final t in _demoTickets)
          if (t.id == ticketId) update(t) else t,
      ];
    });
  }

  void _triggerPendingAlert({bool force = false}) {
    SystemSound.play(SystemSoundType.alert);
    setState(() => _pendingFlash = true);
    _flashController.forward(from: 0).whenComplete(() {
      if (mounted) setState(() => _pendingFlash = false);
    });
  }

  void _watchPendingAndLive(TicketBoard board) {
    final pending = _pending(board);
    final pendingIds = pending.map((t) => t.id).toSet();
    final newPending = pendingIds.difference(_knownPendingIds);
    if (newPending.isNotEmpty) {
      _knownPendingIds = pendingIds;
      _triggerPendingAlert();
      final ticket = pending.firstWhere((t) => newPending.contains(t.id));
      _pushHistory(
        DispatcherHistoryEntry(
          at: DateTime.now().toUtc(),
          kind: DispatcherHistoryKind.created,
          ticketId: ticket.id,
          summary: 'Tichet nou: ${shortTicketLabel(ticket)}',
          detail: 'Probabilitate Craiova ${ticket.likelihoodLabel}',
        ),
      );
    } else {
      _knownPendingIds = pendingIds;
    }

    if (!_usingDemo(board)) {
      final entry = diffBoardEvent(
        previous: _prevLiveSnapshot,
        next: board.tickets,
        at: DateTime.now().toUtc(),
      );
      if (entry != null) {
        _pushHistory(entry);
      }
      _prevLiveSnapshot = List<Ticket>.of(board.tickets);
    }

    if (_forceDemo && board.hasTickets && !_offeredLiveSwitch) {
      _offeredLiveSwitch = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _offerSwitchToLive(board);
      });
    }
  }

  /// Anyone can report — the dispatcher/admin account included. The reporter
  /// flow works standalone (deps come from CoreScope), so we just push it.
  Future<void> _openReporter() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const ReporterScreen()),
    );
  }

  Future<void> _offerSwitchToLive(TicketBoard board) async {
    final goLive = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tichete live detectate'),
        content: Text(
          'Serverul are ${board.tickets.length} tichet(e). '
          'Oprești modul Demo și treci pe date live?',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Rămân pe Demo'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Treci pe Live'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (goLive == true) {
      setState(() => _forceDemo = false);
    }
  }

  Future<void> _runLiveAction(
    String ticketId,
    Future<bool> Function() action,
  ) async {
    if (_busyIds.contains(ticketId)) return;
    setState(() => _busyIds.add(ticketId));
    try {
      final ok = await action();
      if (!mounted) return;
      if (!ok) {
        final board = CoreScope.boardOf(context);
        final message = board.lastActionError ?? 'Acțiunea a eșuat.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busyIds.remove(ticketId));
      }
    }
  }

  Future<void> _confirm(Session session, TicketBoard board, String ticketId) {
    if (_usingDemo(board)) {
      _patchDemo(
        ticketId,
        (t) => t.copyWith(
          status: TicketStatus.dispatched,
          overrideDeadline: null,
          decidedBy: session.userId,
          updatedAt: DateTime.now().toUtc(),
        ),
      );
      final ticket = _demoTickets.firstWhere((t) => t.id == ticketId);
      _pushHistory(
        DispatcherHistoryEntry(
          at: DateTime.now().toUtc(),
          kind: DispatcherHistoryKind.confirmed,
          ticketId: ticketId,
          summary: 'Confirmat: ${shortTicketLabel(ticket)}',
        ),
      );
      return Future<void>.value();
    }
    return _runLiveAction(
      ticketId,
      () => board.confirm(
        ticketId,
        dispatcherId: session.userId,
        dispatcherName: session.displayName,
      ),
    ).then((_) {
      final t = board.find(ticketId);
      if (t != null) {
        _pushHistory(
          DispatcherHistoryEntry(
            at: DateTime.now().toUtc(),
            kind: DispatcherHistoryKind.confirmed,
            ticketId: ticketId,
            summary: 'Confirmat: ${shortTicketLabel(t)}',
          ),
        );
      }
    });
  }

  Future<void> _deny(
    Session session,
    TicketBoard board,
    String ticketId,
    String reason,
  ) {
    if (_usingDemo(board)) {
      _patchDemo(
        ticketId,
        (t) => t.copyWith(
          status: TicketStatus.denied,
          overrideDeadline: null,
          resolutionNote: reason,
          decidedBy: session.userId,
          updatedAt: DateTime.now().toUtc(),
        ),
      );
      final ticket = _demoTickets.firstWhere((t) => t.id == ticketId);
      _pushHistory(
        DispatcherHistoryEntry(
          at: DateTime.now().toUtc(),
          kind: DispatcherHistoryKind.denied,
          ticketId: ticketId,
          summary: 'Respins: ${shortTicketLabel(ticket)}',
          detail: reason,
        ),
      );
      return Future<void>.value();
    }
    return _runLiveAction(
      ticketId,
      () => board.deny(
        ticketId,
        reason: reason,
        dispatcherId: session.userId,
      ),
    ).then((_) {
      final t = board.find(ticketId);
      if (t != null) {
        _pushHistory(
          DispatcherHistoryEntry(
            at: DateTime.now().toUtc(),
            kind: DispatcherHistoryKind.denied,
            ticketId: ticketId,
            summary: 'Respins: ${shortTicketLabel(t)}',
            detail: reason,
          ),
        );
      }
    });
  }

  Future<void> _denyFlow(
    Session session,
    TicketBoard board,
    String ticketId,
  ) async {
    final reason = await showDenyReasonDialog(context);
    if (reason == null || !mounted) return;
    await _deny(session, board, ticketId, reason);
  }

  Future<void> _reclassify(
    Session session,
    TicketBoard board,
    String ticketId,
    ReclassifyChoice choice,
  ) {
    if (_usingDemo(board)) {
      final type = IncidentTaxonomy.all.firstWhere(
        (t) => t.code == choice.incidentCode,
        orElse: () => IncidentTaxonomy.all.first,
      );
      _patchDemo(
        ticketId,
        (t) => t.copyWith(
          status: TicketStatus.dispatched,
          incidentCode: type.code,
          labelRo: type.labelRo,
          category: type.category,
          urgency: choice.urgency ?? type.urgency,
          primaryDepartments: type.primaryDepartments,
          standbyDepartments: type.standbyDepartments,
          overrideDeadline: null,
          decidedBy: session.userId,
          updatedAt: DateTime.now().toUtc(),
        ),
      );
      final ticket = _demoTickets.firstWhere((t) => t.id == ticketId);
      _pushHistory(
        DispatcherHistoryEntry(
          at: DateTime.now().toUtc(),
          kind: DispatcherHistoryKind.reclassified,
          ticketId: ticketId,
          summary: 'Reclasificat: ${shortTicketLabel(ticket)} → ${type.code}',
        ),
      );
      return Future<void>.value();
    }
    return _runLiveAction(
      ticketId,
      () => board.reclassify(
        ticketId,
        incidentCode: choice.incidentCode,
        urgency: choice.urgency,
        dispatcherId: session.userId,
      ),
    ).then((_) {
      final t = board.find(ticketId);
      if (t != null) {
        _pushHistory(
          DispatcherHistoryEntry(
            at: DateTime.now().toUtc(),
            kind: DispatcherHistoryKind.reclassified,
            ticketId: ticketId,
            summary: 'Reclasificat: ${shortTicketLabel(t)}',
          ),
        );
      }
    });
  }

  Future<void> _reclassifyFlow(
    Session session,
    TicketBoard board,
    String ticketId,
  ) async {
    final choice = await showReclassifyDialog(context);
    if (choice == null || !mounted) return;
    await _reclassify(session, board, ticketId, choice);
  }

  KeyEventResult _onKey(
    Session session,
    TicketBoard board,
    KeyEvent event,
  ) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final pending = _pending(board);
    if (pending.isEmpty) return KeyEventResult.ignored;
    final current = pending.first;

    if (event.logicalKey == LogicalKeyboardKey.digit1 ||
        event.logicalKey == LogicalKeyboardKey.numpad1) {
      _confirm(session, board, current.id);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.digit2 ||
        event.logicalKey == LogicalKeyboardKey.numpad2) {
      _denyFlow(session, board, current.id);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.digit3 ||
        event.logicalKey == LogicalKeyboardKey.numpad3) {
      _reclassifyFlow(session, board, current.id);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Future<void> _clearHistory(TicketBoard board, bool demo) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Golești istoricul?'),
        content: const Text(
          'Tichetele rezolvate și respinse vor fi șterse definitiv. '
          'Tichetele active rămân neatinse.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Anulează'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Golește istoricul'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    if (demo) {
      final before = _demoTickets.where((t) => t.status.isTerminal).length;
      setState(() {
        _demoTickets = _demoTickets
            .where((t) => !t.status.isTerminal)
            .toList(growable: false);
      });
      _showHistorySnack('Istoric demo golit ($before tichete).');
      return;
    }

    final before = board.tickets.where((t) => t.status.isTerminal).length;
    final ok = await board.clearHistory();
    if (!mounted) return;
    _showHistorySnack(
      ok
          ? 'Istoric golit ($before tichete).'
          : (board.lastActionError ?? 'Golirea istoricului a eșuat.'),
    );
  }

  void _showHistorySnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final board = CoreScope.boardOf(context);
    final session = CoreScope.sessionOf(context);
    final compact = MediaQuery.sizeOf(context).width < 720;

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (node, event) => _onKey(session, board, event),
      child: Scaffold(
        backgroundColor: kDispatcherCanvas,
        bottomNavigationBar: ReportActionBar(onPressed: _openReporter),
        appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          title: const Text('Dispecerat Wingman'),
          actions: <Widget>[
            ListenableBuilder(
              listenable: board,
              builder: (context, _) {
                final pendingCount = _pending(board).length;
                final online = board.connected;
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (pendingCount > 0)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Badge(
                          backgroundColor: const Color(0xFFD92D20),
                          label: Text('$pendingCount'),
                          child: const Icon(Icons.notification_important),
                        ),
                      ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: online
                            ? const Color(0xFFECFDF3)
                            : const Color(0xFFFEE4E2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: <Widget>[
                          Icon(
                            Icons.circle,
                            size: 9,
                            color: online
                                ? const Color(0xFF027A48)
                                : const Color(0xFFD92D20),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            online ? 'WSS conectat' : 'WSS deconectat',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                              color: online
                                  ? const Color(0xFF027A48)
                                  : const Color(0xFFD92D20),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(width: 8),
            SegmentedButton<bool>(
              segments: <ButtonSegment<bool>>[
                ButtonSegment<bool>(
                  value: true,
                  label: Text(compact ? 'Demo' : 'Date locale'),
                  icon: Icon(Icons.science, size: 16),
                ),
                ButtonSegment<bool>(
                  value: false,
                  label: Text(compact ? 'Live' : 'Live server'),
                  icon: Icon(Icons.cloud_outlined, size: 16),
                ),
              ],
              selected: <bool>{_forceDemo},
              onSelectionChanged: (value) {
                final demo = value.first;
                setState(() {
                  _forceDemo = demo;
                  if (demo) {
                    _demoTickets = buildDemoTickets();
                    _offeredLiveSwitch = false;
                  }
                });
              },
            ),
            if (!compact) ...<Widget>[
              IconButton(
                tooltip: 'Încarcă scenă demo',
                icon: const Icon(Icons.movie_filter_outlined),
                onPressed: _reloadDemo,
              ),
              PopupMenuButton<DispatcherDensity>(
                tooltip: 'Densitate UI',
                initialValue: _density,
                onSelected: (value) => setState(() => _density = value),
                itemBuilder: (context) => <PopupMenuEntry<DispatcherDensity>>[
                  for (final d in DispatcherDensity.values)
                    PopupMenuItem<DispatcherDensity>(
                      value: d,
                      child: Text(d.labelRo),
                    ),
                ],
                icon: const Icon(Icons.density_medium),
              ),
              IconButton(
                tooltip: 'Reîmprospătează live',
                icon: const Icon(Icons.refresh),
                onPressed: board.refresh,
              ),
            ] else
              PopupMenuButton<String>(
                tooltip: 'Mai multe',
                onSelected: (value) {
                  if (value == 'refresh') {
                    board.refresh();
                  } else if (value == 'demo') {
                    _reloadDemo();
                  } else {
                    setState(() {
                      final values = DispatcherDensity.values;
                      _density = values[(_density.index + 1) % values.length];
                    });
                  }
                },
                itemBuilder: (context) => const <PopupMenuEntry<String>>[
                  PopupMenuItem<String>(
                    value: 'refresh',
                    child: Text('Reîmprospătează live'),
                  ),
                  PopupMenuItem<String>(
                    value: 'demo',
                    child: Text('Încarcă scenă demo'),
                  ),
                  PopupMenuItem<String>(
                    value: 'density',
                    child: Text('Schimbă densitatea'),
                  ),
                ],
                icon: const Icon(Icons.more_vert),
              ),
            IconButton(
              tooltip: 'Contul meu',
              icon: const Icon(Icons.person_outline_rounded),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const AccountScreen(),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Ieși din rol',
              icon: const Icon(Icons.logout),
              onPressed: () => CoreScope.of(context).onSignOut(),
            ),
            const SizedBox(width: 8),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(46),
            child: ListenableBuilder(
              listenable: board,
              builder: (context, _) {
                final historyCount =
                    (_usingDemo(board) ? _demoTickets : board.tickets)
                        .where((ticket) => ticket.status.isTerminal)
                        .length;
                return Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    children: <Widget>[
                      _AdminTabButton(
                        label: 'Coadă',
                        selected: _adminTab == _AdminTab.queue,
                        onTap: () =>
                            setState(() => _adminTab = _AdminTab.queue),
                      ),
                      _AdminTabButton(
                        label: 'Istoric',
                        count: historyCount,
                        selected: _adminTab == _AdminTab.history,
                        onTap: () =>
                            setState(() => _adminTab = _AdminTab.history),
                      ),
                      _AdminTabButton(
                        label: 'Statistici',
                        selected: _adminTab == _AdminTab.stats,
                        onTap: () =>
                            setState(() => _adminTab = _AdminTab.stats),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
        body: SafeArea(
          top: false,
          child: ListenableBuilder(
            listenable: board,
            builder: (context, _) {
              final demo = _usingDemo(board);
              final allTickets = _sourceTickets(board);
              final pending = _pending(board);
              final feed = _feed(board);
              final selected = _findTicket(board, _selectedTicketId);
              final liveCount = board.tickets.length;

              if (_adminTab == _AdminTab.stats) {
                return const StatsPane();
              }

              if (_adminTab == _AdminTab.history) {
                final historyTickets = (demo ? _demoTickets : board.tickets)
                    .where((ticket) => ticket.status.isTerminal)
                    .toList()
                  ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
                return _HistoryPane(
                  tickets: historyTickets,
                  demo: demo,
                  onClear: () => _clearHistory(board, demo),
                );
              }

              return LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 1100;
                  final showDetail = wide && selected != null;

                  final feedPane = _FeedPane(
                    demoMode: demo,
                    liveCount: liveCount,
                    connected: board.connected,
                    lastEventLabel: _lastEventLabel,
                    pendingFlash: _pendingFlash,
                    density: _density,
                    filters: _filters,
                    allTickets: allTickets,
                    pending: pending,
                    feed: feed,
                    selectedTicketId: _selectedTicketId,
                    busyIds: _busyIds,
                    loading: board.loading && !demo,
                    lastError: demo ? null : board.lastError,
                    lastActionError: demo ? null : board.lastActionError,
                    compact: compact,
                    onFiltersChanged: (next) => setState(() => _filters = next),
                    onSelectTicket: (id) =>
                        setState(() => _selectedTicketId = id),
                    onConfirm: (id) => _confirm(session, board, id),
                    onDenyReason: (id, reason) =>
                        _deny(session, board, id, reason),
                    onReclassifyChoice: (id, choice) =>
                        _reclassify(session, board, id, choice),
                    onDenyFlow: (id) => _denyFlow(session, board, id),
                    onReclassifyFlow: (id) =>
                        _reclassifyFlow(session, board, id),
                    onLoadDemoScene: _reloadDemo,
                  );

                  if (!wide) return feedPane;

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      SizedBox(
                        width: 310,
                        child: _FilterSidebar(
                          tickets: allTickets,
                          filters: _filters,
                          demoMode: demo,
                          liveCount: liveCount,
                          history: _history,
                          onChanged: (next) => setState(() => _filters = next),
                          onSelectTicket: (id) =>
                              setState(() => _selectedTicketId = id),
                          onLoadDemoScene: _reloadDemo,
                        ),
                      ),
                      const VerticalDivider(width: 1),
                      Expanded(child: feedPane),
                      if (showDetail) ...[
                        const VerticalDivider(width: 1),
                        SizedBox(
                          width: 380,
                          child: _DetailPane(
                            ticket: selected,
                            history: _history
                                .where((e) => e.ticketId == selected.id)
                                .toList(),
                            onClose: () =>
                                setState(() => _selectedTicketId = null),
                          ),
                        ),
                      ],
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _FeedPane extends StatelessWidget {
  const _FeedPane({
    required this.demoMode,
    required this.liveCount,
    required this.connected,
    required this.lastEventLabel,
    required this.pendingFlash,
    required this.density,
    required this.filters,
    required this.allTickets,
    required this.pending,
    required this.feed,
    required this.selectedTicketId,
    required this.busyIds,
    required this.loading,
    required this.lastError,
    required this.lastActionError,
    required this.compact,
    required this.onFiltersChanged,
    required this.onSelectTicket,
    required this.onConfirm,
    required this.onDenyReason,
    required this.onReclassifyChoice,
    required this.onDenyFlow,
    required this.onReclassifyFlow,
    required this.onLoadDemoScene,
  });

  final bool demoMode;
  final int liveCount;
  final bool connected;
  final String lastEventLabel;
  final bool pendingFlash;
  final DispatcherDensity density;
  final DispatcherFilters filters;
  final List<Ticket> allTickets;
  final List<Ticket> pending;
  final List<Ticket> feed;
  final String? selectedTicketId;
  final Set<String> busyIds;
  final bool loading;
  final String? lastError;
  final String? lastActionError;

  /// Phone layout: skip the big banners/department strip so full tickets fit.
  final bool compact;

  final ValueChanged<DispatcherFilters> onFiltersChanged;
  final ValueChanged<String> onSelectTicket;
  final Future<void> Function(String id) onConfirm;
  final Future<void> Function(String id, String reason) onDenyReason;
  final Future<void> Function(String id, ReclassifyChoice choice)
      onReclassifyChoice;
  final Future<void> Function(String id) onDenyFlow;
  final Future<void> Function(String id) onReclassifyFlow;
  final VoidCallback onLoadDemoScene;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (loading) const LinearProgressIndicator(minHeight: 2),
        // The big WSS/demo banners are desktop-only: on the phone they ate half
        // the screen and pushed the ticket cards out of view.
        if (!compact && demoMode)
          _Banner(
            color: const Color(0xFFE0F2FE),
            text: 'Nu ești pe WSS live — Date locale (demo). '
                'Live pe server: $liveCount tichet(e). '
                'Comenzi pending: 1 Confirmă · 2 Respinge · 3 Reclasifică.',
            icon: Icons.science_outlined,
            actionLabel: 'Încarcă scenă demo',
            onAction: onLoadDemoScene,
          ),
        if (!compact)
          _Banner(
            color:
                connected ? const Color(0xFFECFDF3) : const Color(0xFFFEE4E2),
            text:
                '${connected ? 'WSS OK' : 'WSS DOWN'} · Ultimul eveniment: $lastEventLabel',
            icon: connected ? Icons.bolt : Icons.link_off,
          ),
        if (lastError != null)
          _Banner(
            color: theme.colorScheme.errorContainer,
            text: lastError!,
            icon: Icons.cloud_off_outlined,
          ),
        if (lastActionError != null)
          _Banner(
            color: theme.colorScheme.tertiaryContainer,
            text: lastActionError!,
            icon: Icons.warning_amber_outlined,
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (compact)
                _CompactUrgencyRow(
                  tickets: allTickets,
                  pendingCount: pending.length,
                  connected: connected,
                  onSelect: (urgency) => onFiltersChanged(
                    urgency == null
                        ? filters.copyWith(clearUrgency: true)
                        : filters.copyWith(urgency: urgency),
                  ),
                )
              else
                UrgencySummaryBar(
                  tickets: allTickets,
                  selected: filters.urgency,
                  onSelect: (urgency) => onFiltersChanged(
                    urgency == null
                        ? filters.copyWith(clearUrgency: true)
                        : filters.copyWith(urgency: urgency),
                  ),
                ),
              if (!compact) ...<Widget>[
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    FilterChip(
                      label: const Text('Doar nerezolvate'),
                      selected: filters.unresolvedOnly,
                      onSelected: (v) =>
                          onFiltersChanged(filters.copyWith(unresolvedOnly: v)),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Densitate: ${density.labelRo}',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Distribuție pe departamente',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                DepartmentQueueStrip(
                  tickets: allTickets,
                  selected: filters.department,
                  onSelect: (dept) => onFiltersChanged(
                    filters.copyWith(
                      department: dept,
                      clearDepartment: dept == null,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: <Widget>[
              if (pending.isNotEmpty) ...[
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: pendingFlash
                        ? const Color(0xFF7A271A)
                        : const Color(0xFF1D2939),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: pendingFlash
                          ? const Color(0xFFFEE4E2)
                          : const Color(0xFFD92D20),
                      width: 2,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Text(
                        'Necesită confirmare (5s)',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Zonă contrast pe scenă · taste 1 / 2 / 3',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 10),
                      for (final ticket in pending) ...[
                        AnimatedTicketItem(
                          itemKey: 'pending-${ticket.id}-${ticket.version}',
                          child: OverrideCountdownCard(
                            ticket: ticket,
                            busy: busyIds.contains(ticket.id),
                            selected: selectedTicketId == ticket.id,
                            demoMode: demoMode,
                            onSelect: () => onSelectTicket(ticket.id),
                            onConfirm: () => onConfirm(ticket.id),
                            onDeny: (reason) => onDenyReason(ticket.id, reason),
                            onReclassify: (choice) =>
                                onReclassifyChoice(ticket.id, choice),
                          ),
                        ),
                        SizedBox(height: density.cardGap),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Row(
                children: <Widget>[
                  Text(
                    'Coadă tichete',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE4E7EC),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${feed.length}',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    filters.listLabelRo,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (allTickets.isEmpty)
                const _EmptyState(
                  title: 'Niciun tichet încă',
                  subtitle:
                      'Apasă „Încarcă scenă demo” sau așteaptă rapoarte live.',
                )
              else if (feed.isEmpty && pending.isEmpty)
                const _EmptyState(
                  title: 'Niciun tichet pentru filtrele curente',
                  subtitle: 'Resetează filtrele din stânga.',
                )
              else
                for (final ticket in feed) ...[
                  AnimatedTicketItem(
                    itemKey:
                        '${ticket.id}-${ticket.version}-${ticket.status.wire}',
                    child: TicketFeedCard(
                      ticket: ticket,
                      selected: selectedTicketId == ticket.id,
                      density: density,
                      busy: busyIds.contains(ticket.id),
                      onTap: () => onSelectTicket(ticket.id),
                      onDeny: () => onDenyFlow(ticket.id),
                      onReclassify: () => onReclassifyFlow(ticket.id),
                    ),
                  ),
                  SizedBox(height: density.cardGap),
                ],
            ],
          ),
        ),
      ],
    );
  }
}

class _FilterSidebar extends StatelessWidget {
  const _FilterSidebar({
    required this.tickets,
    required this.filters,
    required this.demoMode,
    required this.liveCount,
    required this.history,
    required this.onChanged,
    required this.onSelectTicket,
    required this.onLoadDemoScene,
  });

  final List<Ticket> tickets;
  final DispatcherFilters filters;
  final bool demoMode;
  final int liveCount;
  final List<DispatcherHistoryEntry> history;
  final ValueChanged<DispatcherFilters> onChanged;
  final ValueChanged<String> onSelectTicket;
  final VoidCallback onLoadDemoScene;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pending = tickets.where((t) => t.isPendingOverride).length;
    final active = tickets.where((t) => t.status.isActive).length;

    return ColoredBox(
      color: kDispatcherSidebar,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Text(
            'Filtre rapide',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${tickets.length} total · $pending pending · $active active',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            demoMode
                ? 'Mod: Date locale · pe server așteaptă $liveCount live'
                : 'Mod: Live de pe server ($liveCount)',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          FilledButton.tonalIcon(
            onPressed: onLoadDemoScene,
            icon: const Icon(Icons.movie_filter_outlined),
            label: const Text('Încarcă scenă demo'),
          ),
          const SizedBox(height: 14),
          FilterChip(
            label: const Text('Doar nerezolvate'),
            selected: filters.unresolvedOnly,
            onSelected: (v) => onChanged(filters.copyWith(unresolvedOnly: v)),
          ),
          const SizedBox(height: 14),
          Text('Zone active', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          ZoneBoard(
            tickets: tickets,
            onSelectZoneTicket: (t) => onSelectTicket(t.id),
          ),
          const SizedBox(height: 14),
          Text('Legendă urgență', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          for (final u in Urgency.values.reversed)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _LegendRow(urgency: u),
            ),
          const SizedBox(height: 12),
          Text('Listă', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          for (final option in const [
            DispatcherListFilter.all,
            DispatcherListFilter.active,
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: ChoiceChip(
                label: Text(_listLabel(option)),
                selected: filters.list == option,
                onSelected: (_) => onChanged(filters.copyWith(list: option)),
              ),
            ),
          const SizedBox(height: 12),
          Text('Urgență', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: <Widget>[
              FilterChip(
                label: const Text('Toate'),
                selected: filters.urgency == null,
                onSelected: (_) =>
                    onChanged(filters.copyWith(clearUrgency: true)),
              ),
              for (final u in Urgency.values)
                FilterChip(
                  label: Text(UrgencyStyle.of(u).label),
                  selected: filters.urgency == u,
                  selectedColor: UrgencyStyle.of(u).fillStrong,
                  onSelected: (selected) => onChanged(
                    selected
                        ? filters.copyWith(urgency: u)
                        : filters.copyWith(clearUrgency: true),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text('Departament', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          for (final dept in Department.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: FilterChip(
                label: Text(dept.labelRo),
                selected: filters.department == dept,
                onSelected: (selected) => onChanged(
                  selected
                      ? filters.copyWith(department: dept)
                      : filters.copyWith(clearDepartment: true),
                ),
              ),
            ),
          const SizedBox(height: 14),
          Text('Istoric acțiuni', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          if (history.isEmpty)
            Text(
              'Nicio acțiune încă.',
              style: theme.textTheme.bodySmall,
            )
          else
            for (final entry in history.take(8))
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '• ${entry.kindLabelRo}: ${entry.summary}',
                  style: theme.textTheme.bodySmall?.copyWith(height: 1.3),
                ),
              ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () => onChanged(const DispatcherFilters()),
            icon: const Icon(Icons.clear_all),
            label: const Text('Resetează filtrele'),
          ),
        ],
      ),
    );
  }

  String _listLabel(DispatcherListFilter filter) => switch (filter) {
        DispatcherListFilter.all => 'Toate',
        DispatcherListFilter.pending => 'Așteaptă confirmare',
        DispatcherListFilter.active => 'Active',
        DispatcherListFilter.closed => 'Închise',
      };
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({required this.urgency});

  final Urgency urgency;

  @override
  Widget build(BuildContext context) {
    final style = UrgencyStyle.of(urgency);
    return Row(
      children: <Widget>[
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: style.accent,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            style.label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: style.onFill,
            ),
          ),
        ),
      ],
    );
  }
}

class _DetailPane extends StatelessWidget {
  const _DetailPane({
    required this.ticket,
    required this.history,
    required this.onClose,
  });

  final Ticket ticket;
  final List<DispatcherHistoryEntry> history;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = UrgencyStyle.of(ticket.urgency);
    return ColoredBox(
      color: Colors.white,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Detaliu tichet',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Închide',
                onPressed: onClose,
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TicketMediaPanel(ticket: ticket, height: 190),
          const SizedBox(height: 12),
          TicketFeedCard(ticket: ticket),
          const SizedBox(height: 16),
          TicketTimeline(ticket: ticket),
          const SizedBox(height: 16),
          Text('Istoric pe tichet', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          if (history.isEmpty)
            Text(
              'Nicio acțiune locală pe acest tichet.',
              style: theme.textTheme.bodySmall,
            )
          else
            for (final entry in history)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '• ${entry.kindLabelRo}: ${entry.detail ?? entry.summary}',
                  style: theme.textTheme.bodySmall,
                ),
              ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: style.fill,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: style.accent.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: <Widget>[
                _DetailRow(label: 'ID', value: ticket.id),
                _DetailRow(label: 'Cod', value: ticket.incidentCode),
                _DetailRow(label: 'Status', value: ticket.status.labelRo),
                _DetailRow(label: 'Urgență', value: ticket.urgency.labelRo),
                _DetailRow(
                    label: 'Probabilitate Craiova',
                    value: ticket.likelihoodLabel),
                _DetailRow(label: 'Sursă AI', value: ticket.aiSource.labelRo),
                _DetailRow(
                  label: 'Decis de',
                  value: ticket.decidedBy ?? 'auto / —',
                ),
                _DetailRow(
                  label: 'Notă',
                  value: ticket.resolutionNote ?? '—',
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text('Transcript', style: theme.textTheme.labelLarge),
          const SizedBox(height: 4),
          SelectableText(
            ticket.transcript.isEmpty ? '—' : ticket.transcript,
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Phone-sized replacement for [UrgencySummaryBar]: one slim row so the ticket
/// list keeps almost the whole screen (the big cards were cutting tickets off).
class _CompactUrgencyRow extends StatelessWidget {
  const _CompactUrgencyRow({
    required this.tickets,
    required this.pendingCount,
    required this.connected,
    required this.onSelect,
  });

  final List<Ticket> tickets;
  final int pendingCount;
  final bool connected;
  final ValueChanged<Urgency?> onSelect;

  int _count(Urgency urgency) => tickets
      .where((ticket) => ticket.urgency == urgency && ticket.status.isActive)
      .length;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE4E7EC)),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            Icons.circle,
            size: 9,
            color:
                connected ? const Color(0xFF027A48) : const Color(0xFFD92D20),
          ),
          const SizedBox(width: 6),
          Text(
            connected ? 'LIVE' : 'OFF',
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: Color(0xFF475467),
            ),
          ),
          const SizedBox(width: 10),
          for (final urgency in Urgency.values) ...<Widget>[
            _pill(urgency),
            const SizedBox(width: 6),
          ],
          if (pendingCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE4E2),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$pendingCount în 5s',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFB42318),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _pill(Urgency urgency) {
    final color = switch (urgency) {
      Urgency.critical => const Color(0xFFD92D20),
      Urgency.high => const Color(0xFFDC6803),
      Urgency.medium => const Color(0xFFB54708),
      Urgency.low => const Color(0xFF027A48),
    };
    final background = switch (urgency) {
      Urgency.critical => const Color(0xFFFEF3F2),
      Urgency.high => const Color(0xFFFFFAEB),
      Urgency.medium => const Color(0xFFFFFAEB),
      Urgency.low => const Color(0xFFECFDF3),
    };
    return Expanded(
      child: GestureDetector(
        onTap: () => onSelect(urgency),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                '${_count(urgency)}',
                style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
              Text(
                urgency.labelRo,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: color, fontSize: 8, height: 1.2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.color,
    required this.text,
    required this.icon,
    this.actionLabel,
    this.onAction,
  });

  final Color color;
  final String text;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: <Widget>[
            Icon(icon, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style:
                    const TextStyle(fontWeight: FontWeight.w600, height: 1.3),
              ),
            ),
            if (actionLabel != null && onAction != null)
              TextButton(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 12),
      child: Column(
        children: <Widget>[
          Icon(
            Icons.inbox_outlined,
            size: 48,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

enum _AdminTab { queue, history, stats }

class _AdminTabButton extends StatelessWidget {
  const _AdminTabButton({
    required this.label,
    required this.selected,
    required this.onTap,
    this.count,
  });

  final String label;
  final int? count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? theme.colorScheme.primary : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: selected
                    ? theme.colorScheme.primary
                    : const Color(0xFF64748B),
              ),
            ),
            if (count != null && count! > 0) ...<Widget>[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2F8),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF334155),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HistoryPane extends StatelessWidget {
  const _HistoryPane({
    required this.tickets,
    required this.demo,
    required this.onClear,
  });

  final List<Ticket> tickets;
  final bool demo;
  final Future<void> Function() onClear;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'Istoric',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '${tickets.length} tichete rezolvate sau respinse'
                      '${demo ? ' (demo)' : ''}',
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: tickets.isEmpty ? null : onClear,
                icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                label: const Text('Golește istoricul'),
              ),
            ],
          ),
        ),
        Expanded(
          child: tickets.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(Icons.history_rounded,
                          size: 42, color: Color(0xFF94A3B8)),
                      SizedBox(height: 8),
                      Text(
                        'Istoricul este gol.',
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: tickets.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) =>
                      _HistoryCard(ticket: tickets[index]),
                ),
        ),
      ],
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.ticket});

  final Ticket ticket;

  String get _time {
    final local = ticket.updatedAt.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(local.day)}.${two(local.month)} ${two(local.hour)}:${two(local.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final resolved = ticket.status == TicketStatus.resolved;
    final color = resolved ? const Color(0xFF027A48) : const Color(0xFFB42318);
    final fill = resolved ? const Color(0xFFECFDF3) : const Color(0xFFFEF3F2);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: fill,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  ticket.status.labelRo,
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const Spacer(),
              ReporterCountChip(ticket: ticket),
              const SizedBox(width: 8),
              Text(
                ticket.incidentCode,
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _time,
                style: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            ticket.labelRo,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            '${ticket.location.display} · ${ticket.reporterName}',
            style: const TextStyle(color: Color(0xFF475569), fontSize: 12),
          ),
          if (ticket.photoBase64 != null ||
              (ticket.location.lat != null &&
                  ticket.location.lng != null)) ...<Widget>[
            const SizedBox(height: 10),
            TicketMediaPanel(ticket: ticket, height: 140, compact: true),
          ],
          const SizedBox(height: 3),
          Text(
            ticket.resolutionNote?.trim().isNotEmpty == true
                ? ticket.resolutionNote!
                : 'Fără notă',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
          ),
          if (ticket.decidedBy != null) ...<Widget>[
            const SizedBox(height: 5),
            Text(
              'Decis de ${ticket.decidedBy}',
              style: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
