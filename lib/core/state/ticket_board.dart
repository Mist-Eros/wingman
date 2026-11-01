// =============================================================================
// lib/core/state/ticket_board.dart
//
// OWNER: Lead (lib/core/).
//
// The shared live ticket list every screen reads. It merges:
//   1. the initial `GET /api/tickets` snapshot, and
//   2. every `ticket.*` WSS event,
// so the reporter, dispatcher and crew screens never re-implement the same
// cache/reconnect/sort logic (and never disagree with each other).
//
// Usage in a feature screen:
//   final board = CoreScope.boardOf(context);
//   return ListenableBuilder(
//     listenable: board,
//     builder: (context, _) => ListView(...board.tickets...),
//   );
// =============================================================================

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../api/api_client.dart';
import '../incidents/taxonomy.dart';
import '../models/ticket.dart';

class TicketBoard extends ChangeNotifier {
  TicketBoard({required ApiClient api, this.maxTickets = 300}) : _api = api;

  final ApiClient _api;

  /// Hard cap so a runaway demo loop can't grow the list forever.
  final int maxTickets;

  final Map<String, Ticket> _byId = <String, Ticket>{};
  List<Ticket> _sorted = const <Ticket>[];

  StreamSubscription<ServerEvent>? _subscription;
  bool _started = false;
  bool _disposed = false;
  bool _loading = false;
  bool _connected = false;
  String? _lastError;
  String? _lastActionError;

  /// Sorted for the dashboard: pending override first, then urgency desc,
  /// then newest first.
  List<Ticket> get tickets => _sorted;

  bool get loading => _loading;

  /// WSS link status — show a red "reconectare..." banner when false.
  bool get connected => _connected;

  /// Last error from a background refresh (read/connection), if any.
  String? get lastError => _lastError;

  /// Last error from a user action (confirm/deny/join/vote).
  String? get lastActionError => _lastActionError;

  bool get isEmpty => _sorted.isEmpty;
  bool get hasTickets => _sorted.isNotEmpty;

  List<Ticket> get activeTickets =>
      _sorted.where((ticket) => ticket.status.isActive).toList(growable: false);

  List<Ticket> get pendingOverrides => _sorted
      .where((ticket) => ticket.status == TicketStatus.pendingOverride)
      .toList(growable: false);

  Ticket? find(String ticketId) => _byId[ticketId];

  /// Ids of tickets dispatched to [department] (primary first, standby too).
  List<Ticket> forDepartment(Department department) => _sorted
      .where((ticket) =>
          ticket.primaryDepartments.contains(department) ||
          ticket.standbyDepartments.contains(department))
      .toList(growable: false);

  /// Starts the WSS listener and loads the initial snapshot. Safe to call
  /// twice (main.dart calls it once at boot).
  Future<void> start() async {
    if (_disposed || _started) return;
    _started = true;
    _subscription ??= _api.connectEvents().listen(_onEvent);
    await refresh();
  }

  /// Pull-to-refresh / recovery after a socket outage.
  Future<void> refresh() async {
    if (_disposed) return;
    _loading = true;
    _notify();
    try {
      final tickets = await _api.listTickets();
      _byId
        ..clear()
        ..addEntries(tickets.map((ticket) => MapEntry(ticket.id, ticket)));
      _lastError = null;
    } on ApiException catch (error) {
      _lastError = error.isNetworkIssue
          ? 'Nu pot contacta serverul. Verifică rețeaua și încearcă din nou.'
          : error.message;
    } on Object catch (error) {
      debugPrint('[board] refresh failed: $error');
      _lastError = 'Eroare neașteptată la încărcarea tichetelor.';
    } finally {
      _loading = false;
      _resort();
      _notify();
    }
  }

  /// Applies a decoded WSS event. Public so screens can replay cached events
  /// (and so tests can feed `ServerEvent`s directly).
  void applyEvent(ServerEvent event) => _onEvent(event);

  Future<bool> confirm(
    String ticketId, {
    String? dispatcherId,
    String? dispatcherName,
  }) =>
      _run(() => _api.confirm(
            ticketId,
            dispatcherId: dispatcherId,
            dispatcherName: dispatcherName,
          ));

  Future<bool> confirmResolution(
    String ticketId, {
    String? dispatcherId,
    String? dispatcherName,
  }) =>
      _run(() => _api.confirmResolution(
            ticketId,
            dispatcherId: dispatcherId,
            dispatcherName: dispatcherName,
          ));

  Future<bool> deny(
    String ticketId, {
    String? reason,
    String? dispatcherId,
  }) =>
      _run(() => _api.deny(
            ticketId,
            reason: reason,
            dispatcherId: dispatcherId,
          ));

  Future<bool> reclassify(
    String ticketId, {
    required String incidentCode,
    Urgency? urgency,
    String? reason,
    String? dispatcherId,
  }) =>
      _run(() => _api.reclassify(
            ticketId,
            incidentCode: incidentCode,
            urgency: urgency,
            reason: reason,
            dispatcherId: dispatcherId,
          ));

  /// Admin history tab: remove all resolved/denied tickets server-side.
  Future<bool> clearHistory() async {
    try {
      await _api.clearHistory();
      await refresh();
      _lastActionError = null;
      _notify();
      return true;
    } on ApiException catch (error) {
      _lastActionError = error.isNetworkIssue
          ? 'Nu am putut goli istoricul — serverul nu răspunde.'
          : error.message;
      _notify();
      return false;
    } on Object catch (error) {
      debugPrint('[board] clearHistory failed: $error');
      _lastActionError = 'Golirea istoricului a eșuat. Reîncearcă.';
      _notify();
      return false;
    }
  }

  Future<bool> join(
    String ticketId, {
    required String crewId,
    required String department,
    String? crewName,
  }) =>
      _run(() => _api.join(
            ticketId,
            crewId: crewId,
            department: department,
            crewName: crewName,
          ));

  Future<bool> leave(String ticketId, {required String crewId}) =>
      _run(() => _api.leave(ticketId, crewId: crewId));

  Future<bool> vote(
    String ticketId, {
    required String crewId,
    bool approve = true,
  }) =>
      _run(() => _api.vote(ticketId, crewId: crewId, approve: approve));

  // ── Internals ─────────────────────────────────────────────────────────────

  void _onEvent(ServerEvent event) {
    if (_disposed) return;
    if (event.isConnectionEvent) {
      _connected = event.isConnected;
      if (!_connected && event.detail != null) {
        debugPrint('[board] WSS interrupted: ${event.detail}');
        _lastError = 'Conexiune live întreruptă. Reîncerc automat…';
      }
      if (_connected) {
        _lastError = null;
      }
      _notify();
      return;
    }
    if (event.type == ServerEvent.typeStoreReset) {
      // The demo reset endpoint clears the backend store. Drop stale cards so a
      // crew phone doesn't keep showing tickets that no longer exist (which
      // would make Join/Vote return 404).
      _byId.clear();
      _sorted = const <Ticket>[];
      _lastActionError = 'Serverul a fost resetat — lista a fost golită.';
      _notify();
      return;
    }
    if (event.type == ServerEvent.typeHistoryCleared) {
      final ids = event.data['ticket_ids'];
      if (ids is List) {
        for (final id in ids.whereType<String>()) {
          _byId.remove(id);
        }
        _resort();
        _notify();
      }
      return;
    }
    final ticket = event.ticket;
    if (ticket == null) return;
    _upsert(ticket);
    _notify();
  }

  void _upsert(Ticket ticket) {
    final existing = _byId[ticket.id];
    if (existing != null && existing.version > ticket.version) {
      // Out-of-order delivery: keep the newer state we already have.
      return;
    }
    // Replace lists so `Ticket` instances are never mutated in place.
    _byId[ticket.id] = ticket;
    _resort();
  }

  Future<bool> _run(Future<Ticket> Function() action) async {
    try {
      final ticket = await action();
      _lastActionError = null;
      _upsert(ticket);
      _notify();
      return true;
    } on ApiException catch (error) {
      if (error.statusCode == 404) {
        // Ticket was removed (usually by a demo/dev reset). Reload instead of
        // leaving a dead card on screen; show a friendly message, not HTTP 404.
        _lastActionError = 'Tichetul nu mai există — lista a fost reîncărcată.';
        await refresh();
        _notify();
        return false;
      }
      _lastActionError = error.isNetworkIssue
          ? 'Nu am putut trimite acțiunea — serverul nu răspunde. Reîncearcă.'
          : error.message;
      _notify();
      return false;
    } on Object catch (error) {
      debugPrint('[board] action failed: $error');
      _lastActionError = 'Acțiunea a eșuat. Reîncearcă.';
      _notify();
      return false;
    }
  }

  void _resort() {
    final list = _byId.values.toList(growable: false);
    list.sort(_compareTickets);
    _sorted = List<Ticket>.unmodifiable(
      list.length > maxTickets ? list.take(maxTickets) : list,
    );
  }

  static int _compareTickets(Ticket a, Ticket b) {
    final byStatus = a.status.sortOrder.compareTo(b.status.sortOrder);
    if (byStatus != 0) return byStatus;
    final byUrgency = b.urgency.level.compareTo(a.urgency.level);
    if (byUrgency != 0) return byUrgency;
    final byCreated = b.createdAt.compareTo(a.createdAt);
    if (byCreated != 0) return byCreated;
    return a.id.compareTo(b.id);
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _subscription?.cancel();
    _subscription = null;
    super.dispose();
  }
}
