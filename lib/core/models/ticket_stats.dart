/// Wire model for `GET /api/stats?period=day|week|month|year`.
class TicketStats {
  const TicketStats({
    required this.period,
    required this.totalTickets,
    required this.totalReports,
    required this.resolved,
    required this.denied,
    required this.active,
    required this.byCode,
    required this.byUrgency,
    required this.byDepartment,
    required this.series,
  });

  final String period;
  final int totalTickets;
  final int totalReports;
  final int resolved;
  final int denied;
  final int active;
  final List<CodeStat> byCode;
  final Map<String, int> byUrgency;
  final List<DepartmentStat> byDepartment;
  final List<SeriesPoint> series;

  factory TicketStats.fromJson(Map<String, dynamic> json) {
    return TicketStats(
      period: _str(json['period'], 'week'),
      totalTickets: _int(json['total_tickets']),
      totalReports: _int(json['total_reports']),
      resolved: _int(json['resolved']),
      denied: _int(json['denied']),
      active: _int(json['active']),
      byCode: <CodeStat>[
        if (json['by_code'] is List)
          for (final raw in json['by_code'] as List)
            if (raw is Map<String, dynamic>) CodeStat.fromJson(raw),
      ],
      byUrgency: <String, int>{
        if (json['by_urgency'] is Map)
          for (final entry in (json['by_urgency'] as Map).entries)
            entry.key.toString(): _int(entry.value),
      },
      byDepartment: <DepartmentStat>[
        if (json['by_department'] is List)
          for (final raw in json['by_department'] as List)
            if (raw is Map<String, dynamic>) DepartmentStat.fromJson(raw),
      ],
      series: <SeriesPoint>[
        if (json['series'] is List)
          for (final raw in json['series'] as List)
            if (raw is Map<String, dynamic>) SeriesPoint.fromJson(raw),
      ],
    );
  }
}

class CodeStat {
  const CodeStat({
    required this.code,
    required this.labelRo,
    required this.category,
    required this.count,
    required this.reports,
  });

  final String code;
  final String labelRo;
  final String category;
  final int count;
  final int reports;

  factory CodeStat.fromJson(Map<String, dynamic> json) => CodeStat(
        code: _str(json['code'], '?'),
        labelRo: _str(json['labelRo'], ''),
        category: _str(json['category'], ''),
        count: _int(json['count']),
        reports: _int(json['reports']),
      );
}

class DepartmentStat {
  const DepartmentStat({required this.department, required this.count});
  final String department;
  final int count;
  factory DepartmentStat.fromJson(Map<String, dynamic> json) => DepartmentStat(
        department: _str(json['department'], '?'),
        count: _int(json['count']),
      );
}

class SeriesPoint {
  const SeriesPoint({required this.label, required this.count});
  final String label;
  final int count;
  factory SeriesPoint.fromJson(Map<String, dynamic> json) => SeriesPoint(
        label: _str(json['label'], ''),
        count: _int(json['count']),
      );
}

String _str(Object? value, String fallback) =>
    value is String && value.isNotEmpty ? value : fallback;
int _int(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return 0;
}
