import 'package:flutter_test/flutter_test.dart';
import 'package:wingman/core/widgets/ticket_timer.dart';

void main() {
  test('formats live ticket elapsed time', () {
    expect(
      formatTicketElapsed(const Duration(minutes: 2, seconds: 3)),
      '02:03',
    );
    expect(
      formatTicketElapsed(const Duration(hours: 1, minutes: 2, seconds: 3)),
      '1:02:03',
    );
    expect(
      formatTicketElapsed(
        const Duration(days: 2, hours: 3, minutes: 4, seconds: 5),
      ),
      '2d 03:04',
    );
  });

  test('formats average handling time for stats cards', () {
    expect(formatAverageHandling(null), '—');
    expect(formatAverageHandling(45), '45s');
    expect(formatAverageHandling(125), '2m 05s');
    expect(formatAverageHandling(3661), '1h 01m');
  });
}
