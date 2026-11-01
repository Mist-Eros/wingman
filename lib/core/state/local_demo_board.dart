import 'dart:math';

import '../api/api_client.dart';
import '../incidents/taxonomy.dart';
import '../models/ticket.dart';
import 'ticket_board.dart';

/// Fully local implementation of the shared board.
///
/// It uses the same [Ticket] model and the same screen APIs as the live board,
/// but no HTTP/WSS. A demo action is applied to the in-memory list immediately,
/// so a flaky USB reverse or a slow laptop cannot produce a "server does not
/// answer" error during the judged flow.
///
/// The backend/database remain available for the live build; this class is only
/// selected with `--dart-define=LOCAL_MOCK=true`.
class LocalDemoBoard extends TicketBoard {
  LocalDemoBoard({
    required ApiClient api,
    required List<Ticket> seedTickets,
  })  : _tickets = List<Ticket>.of(seedTickets),
        super(api: api);

  final List<Ticket> _tickets;

  bool _started = false;
  bool _disposed = false;
  String? _lastError;
  String? _lastActionError;

  @override
  bool get connected => true;

  @override
  bool get isLocalDemo => true;

  @override
  bool get loading => false;

  @override
  String? get lastError => _lastError;

  @override
  String? get lastActionError => _lastActionError;

  @override
  List<Ticket> get tickets => _sorted();

  @override
  bool get isEmpty => _tickets.isEmpty;

  @override
  bool get hasTickets => _tickets.isNotEmpty;

  @override
  List<Ticket> get activeTickets =>
      _sorted().where((ticket) => ticket.status.isActive).toList(
            growable: false,
          );

  @override
  List<Ticket> get pendingOverrides => _sorted()
      .where((ticket) => ticket.status == TicketStatus.pendingOverride)
      .toList(growable: false);

  @override
  Ticket? find(String ticketId) {
    for (final ticket in _tickets) {
      if (ticket.id == ticketId) return ticket;
    }
    return null;
  }

  @override
  List<Ticket> forDepartment(Department department) => _sorted()
      .where(
        (ticket) =>
            ticket.primaryDepartments.contains(department) ||
            ticket.standbyDepartments.contains(department),
      )
      .toList(growable: false);

  @override
  Future<void> start() async {
    if (_disposed || _started) return;
    _started = true;
    notifyListeners();
  }

  @override
  Future<void> refresh() async {
    if (_disposed) return;
    _lastError = null;
    notifyListeners();
  }

  @override
  Future<bool> join(
    String ticketId, {
    required String crewId,
    required String department,
    String? crewName,
  }) async {
    final current = find(ticketId);
    if (current == null) {
      _lastActionError = 'Tichetul nu mai există.';
      notifyListeners();
      return false;
    }
    if (!current.status.isActive ||
        current.status == TicketStatus.pendingOverride ||
        current.status == TicketStatus.pendingResolution) {
      _lastActionError = 'Tichetul nu mai poate fi preluat.';
      notifyListeners();
      return false;
    }
    final parsed = Department.tryFromWire(department);
    if (parsed == null || !current.primaryDepartments.contains(parsed)) {
      _lastActionError = 'Doar echipele primare pot prelua acest tichet.';
      notifyListeners();
      return false;
    }
    final joined = List<String>.of(current.joinedCrewIds);
    final departments = List<String>.of(current.joinedDepartments);
    while (departments.length < joined.length) {
      departments.add('');
    }
    if (joined.contains(crewId)) {
      final index = joined.indexOf(crewId);
      if (departments[index] != department) {
        _lastActionError = 'Echipajul este deja preluat pe alt departament.';
        notifyListeners();
        return false;
      }
    } else {
      if (departments.contains(department)) {
        _lastActionError =
            'Un responder din acest departament a preluat deja tichetul.';
        notifyListeners();
        return false;
      }
      joined.add(crewId);
      departments.add(department);
    }
    _lastActionError = null;
    _replace(
      current.copyWith(
        joinedCrewIds: joined,
        joinedDepartments: departments,
        status: TicketStatus.inProgress,
        updatedAt: DateTime.now().toUtc(),
        version: current.version + 1,
      ),
    );
    return true;
  }

  @override
  Future<bool> leave(String ticketId, {required String crewId}) async {
    final current = find(ticketId);
    if (current == null) {
      _lastActionError = 'Tichetul nu mai există.';
      notifyListeners();
      return false;
    }
    final joined = current.joinedCrewIds.where((id) => id != crewId).toList();
    final departments = <String>[];
    for (var i = 0; i < current.joinedCrewIds.length; i++) {
      if (current.joinedCrewIds[i] == crewId) continue;
      if (i < current.joinedDepartments.length) {
        departments.add(current.joinedDepartments[i]);
      }
    }
    final voters = current.resolveVoterIds.where((id) => id != crewId).toList();
    _lastActionError = null;
    _replace(
      current.copyWith(
        joinedCrewIds: joined,
        joinedDepartments: departments,
        resolveVoterIds: voters,
        resolveVotes: voters.length,
        status: joined.isEmpty ? TicketStatus.dispatched : current.status,
        updatedAt: DateTime.now().toUtc(),
        version: current.version + 1,
      ),
    );
    return true;
  }

  @override
  Future<bool> vote(
    String ticketId, {
    required String crewId,
    bool approve = true,
  }) async {
    final current = find(ticketId);
    if (current == null) {
      _lastActionError = 'Tichetul nu mai există.';
      notifyListeners();
      return false;
    }
    if (!current.joinedCrewIds.contains(crewId)) {
      _lastActionError = 'Preia tichetul înainte să votezi.';
      notifyListeners();
      return false;
    }
    if (current.hasVotedBy(crewId)) {
      _lastActionError = null;
      return true;
    }
    final voters = <String>[...current.resolveVoterIds, crewId];
    final votes = voters.length;
    final resolved = votes >= current.quorum;
    final needsAdmin =
        current.urgency == Urgency.high || current.urgency == Urgency.critical;
    final status = !resolved
        ? current.status
        : needsAdmin
            ? TicketStatus.pendingResolution
            : TicketStatus.resolved;
    _lastActionError = null;
    _replace(
      current.copyWith(
        resolveVoterIds: voters,
        resolveVotes: votes,
        status: status,
        resolvedAt: status == TicketStatus.resolved
            ? DateTime.now().toUtc()
            : current.resolvedAt,
        updatedAt: DateTime.now().toUtc(),
        version: current.version + 1,
      ),
    );
    return true;
  }

  @override
  Future<bool> confirmResolution(
    String ticketId, {
    String? dispatcherId,
    String? dispatcherName,
  }) async {
    final current = find(ticketId);
    if (current == null || current.status != TicketStatus.pendingResolution) {
      _lastActionError = 'Tichetul nu așteaptă confirmarea adminului.';
      notifyListeners();
      return false;
    }
    _lastActionError = null;
    _replace(
      current.copyWith(
        status: TicketStatus.resolved,
        resolvedAt: DateTime.now().toUtc(),
        decidedBy: dispatcherId,
        resolutionNote: 'Rezolvare confirmată local',
        updatedAt: DateTime.now().toUtc(),
        version: current.version + 1,
      ),
    );
    return true;
  }

  @override
  Future<bool> confirm(
    String ticketId, {
    String? dispatcherId,
    String? dispatcherName,
  }) async {
    final current = find(ticketId);
    if (current == null) return false;
    _replace(
      current.copyWith(
        status: TicketStatus.dispatched,
        overrideDeadline: null,
        decidedBy: dispatcherId,
        updatedAt: DateTime.now().toUtc(),
        version: current.version + 1,
      ),
    );
    return true;
  }

  @override
  Future<bool> deny(
    String ticketId, {
    String? reason,
    String? dispatcherId,
  }) async {
    final current = find(ticketId);
    if (current == null) return false;
    _replace(
      current.copyWith(
        status: TicketStatus.denied,
        overrideDeadline: null,
        resolutionNote: reason,
        decidedBy: dispatcherId,
        updatedAt: DateTime.now().toUtc(),
        version: current.version + 1,
      ),
    );
    return true;
  }

  @override
  Future<bool> reclassify(
    String ticketId, {
    required String incidentCode,
    Urgency? urgency,
    String? reason,
    String? dispatcherId,
  }) async {
    final current = find(ticketId);
    final type = IncidentTaxonomy.byCode(incidentCode);
    if (current == null || type == null) return false;
    final nextUrgency = urgency == null || urgency.level < type.urgency.level
        ? type.urgency
        : urgency;
    _replace(
      current.copyWith(
        incidentCode: type.code,
        labelRo: type.labelRo,
        category: type.category,
        urgency: nextUrgency,
        primaryDepartments: type.primaryDepartments,
        standbyDepartments: type.standbyDepartments,
        quorum: max(1, type.primaryDepartments.length),
        resolutionNote: reason,
        decidedBy: dispatcherId,
        updatedAt: DateTime.now().toUtc(),
        version: current.version + 1,
      ),
    );
    return true;
  }

  @override
  Future<bool> clearHistory() async {
    _tickets.removeWhere((ticket) => ticket.status.isTerminal);
    _lastActionError = null;
    notifyListeners();
    return true;
  }

  void _replace(Ticket updated) {
    final index = _tickets.indexWhere((ticket) => ticket.id == updated.id);
    if (index >= 0) {
      _tickets[index] = updated;
    }
    notifyListeners();
  }

  List<Ticket> _sorted() {
    final list = List<Ticket>.of(_tickets);
    list.sort((a, b) {
      final byStatus = a.status.sortOrder.compareTo(b.status.sortOrder);
      if (byStatus != 0) return byStatus;
      final byUrgency = b.urgency.level.compareTo(a.urgency.level);
      if (byUrgency != 0) return byUrgency;
      final byCreated = b.createdAt.compareTo(a.createdAt);
      if (byCreated != 0) return byCreated;
      return a.id.compareTo(b.id);
    });
    return List<Ticket>.unmodifiable(list);
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
