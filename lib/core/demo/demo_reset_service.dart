import '../../core/api/api_client.dart';
import '../../core/state/local_demo_board.dart';
import '../../core/state/ticket_board.dart';

/// Result of restoring the prepared demo state.
class DemoResetResult {
  const DemoResetResult({
    required this.local,
    required this.tickets,
    required this.cleared,
  });

  final bool local;
  final int tickets;
  final int cleared;
}

/// Restores the five prepared demo cases, clearing history and rewards.
///
/// Local mode is reset in memory; live mode asks the backend for an atomic
/// clear + seed, so the dashboard and the phone stay in sync.
class DemoResetService {
  const DemoResetService({required this.api, required this.board});

  final ApiClient api;
  final TicketBoard board;

  Future<DemoResetResult> resetPrepared() async {
    if (board is LocalDemoBoard) {
      final count = (board as LocalDemoBoard).resetToSeed();
      return DemoResetResult(local: true, tickets: count, cleared: 0);
    }
    await api.resetPreparedDemo();
    await board.refresh();
    return DemoResetResult(
      local: false,
      tickets: board.tickets.length,
      cleared: 0,
    );
  }

  /// Backwards-compatible name used by older DevTools builds.
  Future<void> reset() async {
    await resetPrepared();
  }
}
