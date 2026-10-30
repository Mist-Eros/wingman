// =============================================================================
// OWNER: Friend 2 (lib/features/dispatcher/).
//
// Frozen contract for main.dart:
//   • class name: DispatcherScreen
//   • const constructor, no required arguments
//   • deps via CoreScope.sessionOf / boardOf
// =============================================================================

import 'package:flutter/material.dart';

import '../../core/core_scope.dart';
import '../../core/incidents/taxonomy.dart';
import '../../core/models/session.dart';
import '../../core/models/ticket.dart';
import '../../core/state/ticket_board.dart';
import 'demo_tickets.dart';
import 'department_queue_strip.dart';
import 'dispatcher_dialogs.dart';
import 'dispatcher_filters.dart';
import 'override_countdown_card.dart';
import 'ticket_feed_card.dart';
import 'urgency_style.dart';

class DispatcherScreen extends StatefulWidget {
  const DispatcherScreen({super.key});

  @override
  State<DispatcherScreen> createState() => _DispatcherScreenState();
}

class _DispatcherScreenState extends State<DispatcherScreen> {
  DispatcherFilters _filters = const DispatcherFilters();
  String? _selectedTicketId;
  final Set<String> _busyIds = <String>{};

  /// Demo stays on until live tickets arrive, unless user forces it.
  bool _forceDemo = true;
  late List<Ticket> _demoTickets;

  @override
  void initState() {
    super.initState();
    _demoTickets = buildDemoTickets();
  }

  bool _usingDemo(TicketBoard board) =>
      _forceDemo || board.isEmpty;

  List<Ticket> _sourceTickets(TicketBoard board) =>
      _usingDemo(board) ? _demoTickets : board.tickets;

  List<Ticket> _pending(TicketBoard board) {
    if (_usingDemo(board)) {
      return _demoTickets.where((t) => t.isPendingOverride).toList();
    }
    return board.pendingOverrides;
  }

  List<Ticket> _feed(TicketBoard board) {
    if (_usingDemo(board)) {
      return _filters.applyToList(_demoTickets, excludePending: true);
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

  void _reloadDemo() {
    setState(() {
      _demoTickets = buildDemoTickets();
      _selectedTicketId = null;
    });
  }

  void _patchDemo(String ticketId, Ticket Function(Ticket) update) {
    setState(() {
      _demoTickets = <Ticket>[
        for (final t in _demoTickets)
          if (t.id == ticketId) update(t) else t,
      ];
    });
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
      return Future<void>.value();
    }
    return _runLiveAction(
      ticketId,
      () => board.confirm(
            ticketId,
            dispatcherId: session.userId,
            dispatcherName: session.displayName,
          ),
    );
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
      return Future<void>.value();
    }
    return _runLiveAction(
      ticketId,
      () => board.deny(
            ticketId,
            reason: reason,
            dispatcherId: session.userId,
          ),
    );
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final board = CoreScope.boardOf(context);
    final session = CoreScope.sessionOf(context);

    return Scaffold(
      backgroundColor: kDispatcherCanvas,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: const Text('Dispecerat Wingman'),
        actions: <Widget>[
          ListenableBuilder(
            listenable: board,
            builder: (context, _) {
              final online = board.connected;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Center(
                  child: Container(
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
                      mainAxisSize: MainAxisSize.min,
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
                ),
              );
            },
          ),
          const SizedBox(width: 4),
          FilterChip(
            label: Text(_forceDemo ? 'Demo ON' : 'Demo OFF'),
            selected: _forceDemo,
            avatar: Icon(
              _forceDemo ? Icons.science : Icons.cloud_outlined,
              size: 16,
            ),
            onSelected: (value) {
              setState(() {
                _forceDemo = value;
                if (value) _reloadDemo();
              });
            },
          ),
          if (_forceDemo)
            IconButton(
              tooltip: 'Regenerează tickete demo',
              icon: const Icon(Icons.restart_alt),
              onPressed: _reloadDemo,
            ),
          IconButton(
            tooltip: 'Reîmprospătează live',
            icon: const Icon(Icons.refresh),
            onPressed: board.refresh,
          ),
          IconButton(
            tooltip: 'Ieși din rol',
            icon: const Icon(Icons.logout),
            onPressed: () => CoreScope.of(context).onSignOut(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListenableBuilder(
        listenable: board,
        builder: (context, _) {
          final demo = _usingDemo(board);
          final allTickets = _sourceTickets(board);
          final pending = _pending(board);
          final feed = _feed(board);
          final selected = _findTicket(board, _selectedTicketId);

          return LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 1100;
              final showDetail = wide && selected != null;

              final feedPane = _FeedPane(
                demoMode: demo,
                filters: _filters,
                allTickets: allTickets,
                pending: pending,
                feed: feed,
                selectedTicketId: _selectedTicketId,
                busyIds: _busyIds,
                loading: board.loading && !demo,
                lastError: demo ? null : board.lastError,
                lastActionError: demo ? null : board.lastActionError,
                onFiltersChanged: (next) => setState(() => _filters = next),
                onSelectTicket: (id) => setState(() => _selectedTicketId = id),
                onConfirm: (id) => _confirm(session, board, id),
                onDeny: (id, reason) => _deny(session, board, id, reason),
                onReclassify: (id, choice) =>
                    _reclassify(session, board, id, choice),
              );

              if (!wide) return feedPane;

              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  SizedBox(
                    width: 300,
                    child: _FilterSidebar(
                      tickets: allTickets,
                      filters: _filters,
                      demoMode: demo,
                      onChanged: (next) => setState(() => _filters = next),
                    ),
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(child: feedPane),
                  if (showDetail) ...[
                    const VerticalDivider(width: 1),
                    SizedBox(
                      width: 360,
                      child: _DetailPane(
                        ticket: selected,
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
    );
  }
}

class _FeedPane extends StatelessWidget {
  const _FeedPane({
    required this.demoMode,
    required this.filters,
    required this.allTickets,
    required this.pending,
    required this.feed,
    required this.selectedTicketId,
    required this.busyIds,
    required this.loading,
    required this.lastError,
    required this.lastActionError,
    required this.onFiltersChanged,
    required this.onSelectTicket,
    required this.onConfirm,
    required this.onDeny,
    required this.onReclassify,
  });

  final bool demoMode;
  final DispatcherFilters filters;
  final List<Ticket> allTickets;
  final List<Ticket> pending;
  final List<Ticket> feed;
  final String? selectedTicketId;
  final Set<String> busyIds;
  final bool loading;
  final String? lastError;
  final String? lastActionError;
  final ValueChanged<DispatcherFilters> onFiltersChanged;
  final ValueChanged<String> onSelectTicket;
  final Future<void> Function(String id) onConfirm;
  final Future<void> Function(String id, String reason) onDeny;
  final Future<void> Function(String id, ReclassifyChoice choice) onReclassify;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (loading) const LinearProgressIndicator(minHeight: 2),
        if (demoMode)
          _Banner(
            color: const Color(0xFFE0F2FE),
            text:
                'Mod demonstrativ — tickete exemplu colorate pe urgență. Oprește Demo când conectezi backend/mobil.',
            icon: Icons.science_outlined,
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
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              UrgencySummaryBar(
                tickets: allTickets,
                selected: filters.urgency,
                onSelect: (urgency) => onFiltersChanged(
                  urgency == null
                      ? filters.copyWith(clearUrgency: true)
                      : filters.copyWith(urgency: urgency),
                ),
              ),
              const SizedBox(height: 12),
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
              const SizedBox(height: 8),
              LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth >= 820) {
                    return const SizedBox.shrink();
                  }
                  return _CompactFilterBar(
                    filters: filters,
                    onChanged: onFiltersChanged,
                  );
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: <Widget>[
              if (pending.isNotEmpty) ...[
                Text(
                  'Necesită confirmare (5s)',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFFD92D20),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tichetele cu încredere mică apar aici înainte de dispecerizare.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 10),
                for (final ticket in pending) ...[
                  OverrideCountdownCard(
                    ticket: ticket,
                    busy: busyIds.contains(ticket.id),
                    selected: selectedTicketId == ticket.id,
                    demoMode: demoMode,
                    onSelect: () => onSelectTicket(ticket.id),
                    onConfirm: () => onConfirm(ticket.id),
                    onDeny: (reason) => onDeny(ticket.id, reason),
                    onReclassify: (choice) =>
                        onReclassify(ticket.id, choice),
                  ),
                  const SizedBox(height: 12),
                ],
                const SizedBox(height: 4),
                const Divider(height: 28),
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
                      'Activează Demo sau așteaptă rapoarte de pe mobil / reporter.',
                )
              else if (feed.isEmpty && pending.isEmpty)
                const _EmptyState(
                  title: 'Niciun tichet pentru filtrele curente',
                  subtitle:
                      'Resetează filtrele sau apasă pe o culoare de urgență din summary.',
                )
              else
                for (final ticket in feed) ...[
                  TicketFeedCard(
                    ticket: ticket,
                    selected: selectedTicketId == ticket.id,
                    onTap: () => onSelectTicket(ticket.id),
                  ),
                  const SizedBox(height: 12),
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
    required this.onChanged,
  });

  final List<Ticket> tickets;
  final DispatcherFilters filters;
  final bool demoMode;
  final ValueChanged<DispatcherFilters> onChanged;

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
          if (demoMode) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFE0F2FE),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Date locale de demonstrație. Când conectezi mobilul, oprește Demo.',
                style: TextStyle(fontSize: 12, height: 1.35),
              ),
            ),
          ],
          const SizedBox(height: 18),
          Text('Legendă urgență', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          for (final u in Urgency.values.reversed)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _LegendRow(urgency: u),
            ),
          const SizedBox(height: 16),
          Text('Listă', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          for (final option in DispatcherListFilter.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: ChoiceChip(
                label: Text(_listLabel(option)),
                selected: filters.list == option,
                onSelected: (_) => onChanged(filters.copyWith(list: option)),
              ),
            ),
          const SizedBox(height: 16),
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
                  checkmarkColor: UrgencyStyle.of(u).accent,
                  onSelected: (selected) => onChanged(
                    selected
                        ? filters.copyWith(urgency: u)
                        : filters.copyWith(clearUrgency: true),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
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
        Container(
          width: 28,
          height: 14,
          decoration: BoxDecoration(
            color: style.fill,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: style.accent.withValues(alpha: 0.4)),
          ),
        ),
      ],
    );
  }
}

class _CompactFilterBar extends StatelessWidget {
  const _CompactFilterBar({
    required this.filters,
    required this.onChanged,
  });

  final DispatcherFilters filters;
  final ValueChanged<DispatcherFilters> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: <Widget>[
          for (final option in DispatcherListFilter.values)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                label: Text(option == DispatcherListFilter.all
                    ? 'Toate'
                    : option == DispatcherListFilter.pending
                        ? 'Pending'
                        : option == DispatcherListFilter.active
                            ? 'Active'
                            : 'Închise'),
                selected: filters.list == option,
                onSelected: (_) => onChanged(filters.copyWith(list: option)),
              ),
            ),
        ],
      ),
    );
  }
}

class _DetailPane extends StatelessWidget {
  const _DetailPane({required this.ticket, required this.onClose});

  final Ticket ticket;
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
          TicketFeedCard(ticket: ticket),
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
                _DetailRow(label: 'Încredere', value: ticket.confidenceLabel),
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

class _Banner extends StatelessWidget {
  const _Banner({
    required this.color,
    required this.text,
    required this.icon,
  });

  final Color color;
  final String text;
  final IconData icon;

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
                style: const TextStyle(fontWeight: FontWeight.w600, height: 1.3),
              ),
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
