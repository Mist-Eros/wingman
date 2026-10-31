import 'package:flutter_test/flutter_test.dart';
import 'package:wingman/core/models/ticket_stats.dart';

void main() {
  test('parses admin statistics payload', () {
    final stats = TicketStats.fromJson(<String, dynamic>{
      'period': 'week',
      'total_tickets': 4,
      'total_reports': 6,
      'resolved': 2,
      'active': 1,
      'by_code': <Map<String, dynamic>>[
        <String, dynamic>{
          'code': 'OP-MED',
          'labelRo': 'Medical',
          'category': 'operations',
          'count': 3,
          'reports': 5,
        },
      ],
      'by_urgency': <String, int>{'high': 2, 'critical': 2},
      'by_department': <Map<String, dynamic>>[
        <String, dynamic>{'department': 'medical', 'count': 3},
      ],
      'series': <Map<String, dynamic>>[
        <String, dynamic>{'label': 'Lun', 'count': 2},
        <String, dynamic>{'label': 'Mar', 'count': 0},
      ],
    });
    expect(stats.period, 'week');
    expect(stats.totalReports, 6);
    expect(stats.byCode.single.code, 'OP-MED');
    expect(stats.byCode.single.reports, 5);
    expect(stats.byDepartment.single.department, 'medical');
    expect(stats.series, hasLength(2));
    expect(stats.byUrgency['critical'], 2);
  });
}
