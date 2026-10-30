// =============================================================================
// LOCAL PREVIEW ONLY — crew feature (Lica Rares Adelin).
// Opens the Crew UI with fake tickets. No backend. Works on Chrome (no dart:io).
//
//   flutter run -t lib/features/crew/crew_preview_main.dart -d chrome
//
// Do NOT ship this as the app entry; main.dart stays Lead-owned.
// =============================================================================

import 'package:flutter/material.dart';

import '../../core/incidents/taxonomy.dart';
import '../../core/models/ticket.dart';
import 'crew_ticket_card.dart';
import 'wss_banner.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _CrewPreviewApp());
}

class _CrewPreviewApp extends StatelessWidget {
  const _CrewPreviewApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: true,
      title: 'Crew Preview',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F766E),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF4F7FB),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF4F7FB),
          foregroundColor: Color(0xFF0F172A),
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        textTheme: ThemeData.light().textTheme.apply(
              bodyColor: const Color(0xFF0F172A),
              displayColor: const Color(0xFF0F172A),
            ),
      ),
      home: const _CrewPreviewScreen(),
    );
  }
}

class _PreviewBoard extends ChangeNotifier {
  _PreviewBoard() {
    final now = DateTime.now().toUtc();
    _tickets = <Ticket>[
      _ticket(
        id: 'preview-dispatched',
        status: TicketStatus.dispatched,
        code: 'SF-FIRE',
        label: 'Foc sau fum în terminal',
        category: IncidentCategory.safetyFire,
        urgency: Urgency.critical,
        zone: 'Poarta 12',
        now: now,
      ),
      _ticket(
        id: 'preview-in-progress',
        status: TicketStatus.inProgress,
        code: 'SC-UNATT',
        label: 'Bagaj nesupravegheat',
        category: IncidentCategory.security,
        urgency: Urgency.high,
        zone: 'Check-in A',
        joined: const <String>['crew-2'],
        now: now,
      ),
    ];
  }

  static const String crewId = 'crew-1';
  static const String crewName = 'Echipaj Preview';

  late List<Ticket> _tickets;
  String? lastActionError;
  bool connected = true;

  List<Ticket> get queue => _tickets
      .where(
        (t) =>
            t.status == TicketStatus.dispatched ||
            t.status == TicketStatus.inProgress,
      )
      .toList(growable: false);

  Ticket? find(String id) {
    for (final t in _tickets) {
      if (t.id == id) return t;
    }
    return null;
  }

  void _replace(Ticket updated) {
    _tickets = <Ticket>[
      for (final t in _tickets)
        if (t.id == updated.id) updated else t,
    ];
    notifyListeners();
  }

  Future<bool> join(String ticketId) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    final current = find(ticketId);
    if (current == null) {
      lastActionError = 'Ticket inexistent';
      notifyListeners();
      return false;
    }
    if (current.isJoinedBy(crewId)) return true;
    lastActionError = null;
    _replace(
      current.copyWith(
        joinedCrewIds: <String>[...current.joinedCrewIds, crewId],
        status: TicketStatus.inProgress,
        version: current.version + 1,
        updatedAt: DateTime.now().toUtc(),
      ),
    );
    return true;
  }

  Future<bool> vote(String ticketId) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    final current = find(ticketId);
    if (current == null) {
      lastActionError = 'Ticket inexistent';
      notifyListeners();
      return false;
    }
    if (current.hasVotedBy(crewId)) return true;
    final votes = current.resolveVotes + 1;
    final voters = <String>[...current.resolveVoterIds, crewId];
    final resolved = votes >= current.quorum;
    lastActionError = null;
    _replace(
      current.copyWith(
        resolveVotes: votes,
        resolveVoterIds: voters,
        status: resolved ? TicketStatus.resolved : current.status,
        version: current.version + 1,
        updatedAt: DateTime.now().toUtc(),
      ),
    );
    return true;
  }
}

class _CrewPreviewScreen extends StatefulWidget {
  const _CrewPreviewScreen();

  @override
  State<_CrewPreviewScreen> createState() => _CrewPreviewScreenState();
}

class _CrewPreviewScreenState extends State<_CrewPreviewScreen> {
  late final _PreviewBoard _board;
  final Map<String, TicketStatus> _seen = <String, TicketStatus>{};

  @override
  void initState() {
    super.initState();
    _board = _PreviewBoard();
    for (final t in _board._tickets) {
      _seen[t.id] = t.status;
    }
    _board.addListener(_onBoard);
  }

  @override
  void dispose() {
    _board.removeListener(_onBoard);
    _board.dispose();
    super.dispose();
  }

  void _onBoard() {
    for (final t in _board._tickets) {
      final prev = _seen[t.id];
      _seen[t.id] = t.status;
      if (prev != null &&
          prev != TicketStatus.resolved &&
          t.status == TicketStatus.resolved &&
          mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Intervenție rezolvată · ${t.incidentCode}'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final queue = _board.queue;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Echipaj',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
                color: Color(0xFF0F172A),
              ),
            ),
            Text(
              _PreviewBoard.crewName,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              Color(0xFFF4F7FB),
              Color(0xFFE8EEF5),
              Color(0xFFE2EAF3),
            ],
          ),
        ),
        child: Column(
          children: <Widget>[
            WssBanner(connected: _board.connected),
            Material(
              color: const Color(0xFFD7F0EB),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                child: Row(
                  children: <Widget>[
                    Icon(
                      Icons.visibility_outlined,
                      size: 16,
                      color: Color(0xFF0F766E),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'PREVIEW local — date fake, fără backend',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F766E),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
                itemCount: queue.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final ticket = queue[index];
                  return TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0, end: 1),
                    duration: Duration(
                      milliseconds: 280 + (index * 40).clamp(0, 160),
                    ),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, child) {
                      return Opacity(
                        opacity: value,
                        child: Transform.translate(
                          offset: Offset(0, 10 * (1 - value)),
                          child: child,
                        ),
                      );
                    },
                    child: CrewTicketCard(
                      key: ValueKey<String>('${ticket.id}-${ticket.version}'),
                      ticket: ticket,
                      crewId: _PreviewBoard.crewId,
                      onJoin: () => _board.join(ticket.id),
                      onVote: () => _board.vote(ticket.id),
                      lastActionError: () => _board.lastActionError,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Ticket _ticket({
  required String id,
  required TicketStatus status,
  required String code,
  required String label,
  required IncidentCategory category,
  required Urgency urgency,
  required String zone,
  required DateTime now,
  List<String> joined = const <String>[],
}) {
  return Ticket(
    id: id,
    incidentCode: code,
    labelRo: label,
    category: category,
    urgency: urgency,
    status: status,
    source: ReportSource.menu,
    reporterId: 'reporter-preview',
    reporterName: 'Reporter Preview',
    transcript: 'Preview local fără backend.',
    location: IncidentLocation(terminal: 'T1', zone: zone),
    confidence: 0.91,
    aiSource: AiSource.manual,
    primaryDepartments: category == IncidentCategory.security
        ? const <Department>[Department.security]
        : const <Department>[Department.fireRescue, Department.security],
    standbyDepartments: const <Department>[Department.operations],
    createdAt: now,
    updatedAt: now,
    joinedCrewIds: joined,
    resolveVotes: 0,
    resolveVoterIds: const <String>[],
    quorum: 2,
    version: 1,
  );
}


