import '../../core/api/api_client.dart';
import '../../core/state/ticket_board.dart';

/// Demo/session reset is its own concern. DevTools, future admin screens or a
/// different application can call this without knowing the endpoint path.
class DemoResetService {
  const DemoResetService({required this.api, required this.board});

  final ApiClient api;
  final TicketBoard board;

  Future<void> reset() async {
    await api.devReset();
    await board.refresh();
  }
}
