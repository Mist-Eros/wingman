import '../../core/models/ticket.dart';

enum DispatcherHistoryKind {
  confirmed,
  denied,
  reclassified,
  autoDispatched,
  joined,
  resolved,
  created,
  observed,
}

class DispatcherHistoryEntry {
  const DispatcherHistoryEntry({
    required this.at,
    required this.kind,
    required this.ticketId,
    required this.summary,
    this.detail,
  });

  final DateTime at;
  final DispatcherHistoryKind kind;
  final String ticketId;
  final String summary;
  final String? detail;

  String get kindLabelRo => switch (kind) {
        DispatcherHistoryKind.confirmed => 'Confirmat',
        DispatcherHistoryKind.denied => 'Respins',
        DispatcherHistoryKind.reclassified => 'Reclasificat',
        DispatcherHistoryKind.autoDispatched => 'Auto-dispecerizat',
        DispatcherHistoryKind.joined => 'Echipaj',
        DispatcherHistoryKind.resolved => 'Rezolvat',
        DispatcherHistoryKind.created => 'Creat',
        DispatcherHistoryKind.observed => 'Actualizat',
      };
}

/// Pending-first, then urgency desc, then newest — keeps critical cards on top.
List<Ticket> sortDispatcherTickets(Iterable<Ticket> tickets) {
  final list = tickets.toList();
  list.sort((a, b) {
    final byPending = (b.isPendingOverride ? 1 : 0)
        .compareTo(a.isPendingOverride ? 1 : 0);
    if (byPending != 0) return byPending;
    final byUrgency = b.urgency.level.compareTo(a.urgency.level);
    if (byUrgency != 0) return byUrgency;
    final byCreated = b.createdAt.compareTo(a.createdAt);
    if (byCreated != 0) return byCreated;
    return a.id.compareTo(b.id);
  });
  return list;
}

String shortTicketLabel(Ticket ticket) {
  final id = ticket.id.startsWith('demo-')
      ? ticket.id.replaceFirst('demo-', '').toUpperCase()
      : (ticket.id.replaceAll('-', '').length <= 8
          ? ticket.id
          : ticket.id.replaceAll('-', '').substring(0, 8).toUpperCase());
  return '$id · ${ticket.incidentCode}';
}

/// Derive a human "last event" line by diffing two ticket snapshots.
DispatcherHistoryEntry? diffBoardEvent({
  required List<Ticket> previous,
  required List<Ticket> next,
  required DateTime at,
}) {
  final prevById = <String, Ticket>{
    for (final t in previous) t.id: t,
  };
  for (final ticket in next) {
    final old = prevById[ticket.id];
    if (old == null) {
      return DispatcherHistoryEntry(
        at: at,
        kind: ticket.isPendingOverride
            ? DispatcherHistoryKind.created
            : DispatcherHistoryKind.created,
        ticketId: ticket.id,
        summary: 'Tichet nou: ${shortTicketLabel(ticket)}',
        detail: ticket.status.labelRo,
      );
    }
    if (old.version == ticket.version && old.status == ticket.status) {
      continue;
    }
    if (old.isPendingOverride &&
        ticket.status == TicketStatus.dispatched &&
        ticket.decidedBy == null) {
      return DispatcherHistoryEntry(
        at: at,
        kind: DispatcherHistoryKind.autoDispatched,
        ticketId: ticket.id,
        summary: 'Auto-dispecerizat: ${shortTicketLabel(ticket)}',
      );
    }
    if (old.status != TicketStatus.resolved &&
        ticket.status == TicketStatus.resolved) {
      return DispatcherHistoryEntry(
        at: at,
        kind: DispatcherHistoryKind.resolved,
        ticketId: ticket.id,
        summary: 'Rezolvat: ${shortTicketLabel(ticket)}',
      );
    }
    if (ticket.joinedCrewIds.length > old.joinedCrewIds.length) {
      return DispatcherHistoryEntry(
        at: at,
        kind: DispatcherHistoryKind.joined,
        ticketId: ticket.id,
        summary:
            'Join: ${shortTicketLabel(ticket)} (${ticket.joinedCrewIds.length})',
      );
    }
    return DispatcherHistoryEntry(
      at: at,
      kind: DispatcherHistoryKind.observed,
      ticketId: ticket.id,
      summary: 'Update: ${shortTicketLabel(ticket)}',
      detail: '${old.status.labelRo} → ${ticket.status.labelRo}',
    );
  }
  return null;
}

String zoneKeyFor(Ticket ticket) {
  final zone = ticket.location.zone.trim();
  if (zone.isNotEmpty) return zone;
  final terminal = ticket.location.terminal.trim();
  if (terminal.isNotEmpty) return terminal;
  return 'Locație nespecificată';
}

Map<String, List<Ticket>> groupTicketsByZone(List<Ticket> tickets) {
  final map = <String, List<Ticket>>{};
  for (final ticket in sortDispatcherTickets(tickets)) {
    map.putIfAbsent(zoneKeyFor(ticket), () => <Ticket>[]).add(ticket);
  }
  final keys = map.keys.toList()
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return <String, List<Ticket>>{
    for (final key in keys) key: map[key]!,
  };
}
