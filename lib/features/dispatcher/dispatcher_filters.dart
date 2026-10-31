import '../../core/incidents/taxonomy.dart';
import '../../core/models/ticket.dart';
import '../../core/state/ticket_board.dart';
import 'dispatcher_history.dart';

/// Status bucket for the dispatcher feed (not a server status).
enum DispatcherListFilter {
  all,
  pending,
  active,
  closed,
}

/// Local UI filter state. Does not mutate [TicketBoard] order except by subset.
class DispatcherFilters {
  const DispatcherFilters({
    this.list = DispatcherListFilter.active,
    this.department,
    this.urgency,
    this.unresolvedOnly = false,
    this.zone,
  });

  final DispatcherListFilter list;
  final Department? department;
  final Urgency? urgency;
  final bool unresolvedOnly;
  final String? zone;

  DispatcherFilters copyWith({
    DispatcherListFilter? list,
    Department? department,
    Urgency? urgency,
    bool? unresolvedOnly,
    String? zone,
    bool clearDepartment = false,
    bool clearUrgency = false,
    bool clearZone = false,
  }) =>
      DispatcherFilters(
        list: list ?? this.list,
        department: clearDepartment ? null : (department ?? this.department),
        urgency: clearUrgency ? null : (urgency ?? this.urgency),
        unresolvedOnly: unresolvedOnly ?? this.unresolvedOnly,
        zone: clearZone ? null : (zone ?? this.zone),
      );

  List<Ticket> apply(
    TicketBoard board, {
    bool excludePending = true,
  }) {
    Iterable<Ticket> source;
    switch (list) {
      case DispatcherListFilter.all:
        source = board.tickets;
      case DispatcherListFilter.pending:
        source = board.pendingOverrides;
      case DispatcherListFilter.active:
        source = board.activeTickets;
      case DispatcherListFilter.closed:
        source = board.tickets.where((t) => t.status.isTerminal);
    }
    return _narrow(source, excludePending: excludePending);
  }

  List<Ticket> applyToList(
    List<Ticket> tickets, {
    bool excludePending = true,
  }) {
    Iterable<Ticket> source;
    switch (list) {
      case DispatcherListFilter.all:
        source = tickets;
      case DispatcherListFilter.pending:
        source = tickets.where((t) => t.isPendingOverride);
      case DispatcherListFilter.active:
        source = tickets.where((t) => t.status.isActive);
      case DispatcherListFilter.closed:
        source = tickets.where((t) => t.status.isTerminal);
    }
    return _narrow(source, excludePending: excludePending);
  }

  List<Ticket> _narrow(
    Iterable<Ticket> source, {
    required bool excludePending,
  }) {
    // The admin view only shows work that is still open. Resolved/denied
    // tickets are clutter and never appear in the queue.
    source = source.where((t) => !t.status.isTerminal);

    if (unresolvedOnly) {
      source = source.where((t) => !t.status.isTerminal);
    }

    if (department != null) {
      final dept = department!;
      source = source.where(
        (t) =>
            t.primaryDepartments.contains(dept) ||
            t.standbyDepartments.contains(dept),
      );
    }

    if (urgency != null) {
      final u = urgency!;
      source = source.where((t) => t.urgency == u);
    }

    if (zone != null && zone!.trim().isNotEmpty) {
      final z = zone!;
      source = source.where((t) => zoneKeyFor(t) == z);
    }

    return List<Ticket>.unmodifiable(
      sortDispatcherTickets(source),
    );
  }

  String get listLabelRo => switch (list) {
        DispatcherListFilter.all => 'Toate',
        DispatcherListFilter.pending => 'Așteaptă confirmare',
        DispatcherListFilter.active => 'Active',
        DispatcherListFilter.closed => 'Închise',
      };
}
