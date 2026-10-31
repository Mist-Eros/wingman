import 'package:flutter/material.dart';

import '../../core/core_scope.dart';
import '../../core/incidents/taxonomy.dart';
import '../../core/models/ticket_stats.dart';
import '../../core/widgets/ticket_timer.dart';
import '../../core/theme/wingman_theme.dart';

/// Admin statistics: what happens, how many and how often, by day/week/month/year.
class StatsPane extends StatefulWidget {
  const StatsPane({super.key});

  @override
  State<StatsPane> createState() => _StatsPaneState();
}

class _StatsPaneState extends State<StatsPane> {
  String _period = 'week';
  Future<TicketStats>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _load();
  }

  Future<TicketStats> _load() {
    return CoreScope.apiOf(context).stats(period: _period);
  }

  void _setPeriod(String period) {
    if (period == _period) return;
    setState(() {
      _period = period;
      _future = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<TicketStats>(
      future: _future,
      builder: (context, snapshot) {
        return ListView(
          padding: const EdgeInsets.all(14),
          children: <Widget>[
            SegmentedButton<String>(
              segments: const <ButtonSegment<String>>[
                ButtonSegment<String>(value: 'day', label: Text('Zi')),
                ButtonSegment<String>(value: 'week', label: Text('Săpt.')),
                ButtonSegment<String>(value: 'month', label: Text('Lună')),
                ButtonSegment<String>(value: 'year', label: Text('An')),
              ],
              selected: <String>{_period},
              onSelectionChanged: (value) => _setPeriod(value.first),
            ),
            const SizedBox(height: 12),
            if (snapshot.connectionState == ConnectionState.waiting)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (snapshot.hasError)
              _ErrorState(
                message: '${snapshot.error}',
                onRetry: () => setState(() => _future = _load()),
              )
            else if (snapshot.data != null)
              _StatsBody(stats: snapshot.data!),
          ],
        );
      },
    );
  }
}

class _StatsBody extends StatelessWidget {
  const _StatsBody({required this.stats});

  final TicketStats stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxCode = stats.byCode.isEmpty ? 0 : stats.byCode.first.count;
    final maxSeries = stats.series.isEmpty
        ? 0
        : stats.series.map((p) => p.count).reduce((a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            _Kpi(value: '${stats.totalTickets}', label: 'tichete'),
            _Kpi(value: '${stats.totalReports}', label: 'raportări'),
            _Kpi(value: '${stats.resolved}', label: 'rezolvate'),
            _Kpi(value: '${stats.active}', label: 'active'),
            _Kpi(
              value: formatAverageHandling(stats.averageHandlingSeconds),
              label: 'timp mediu',
            ),
          ],
        ),
        if (stats.handledCount > 0)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Timp mediu de la raportare la rezolvare, '
              'pe ${stats.handledCount} tichete rezolvate.',
              style: theme.textTheme.bodySmall,
            ),
          ),
        const SizedBox(height: 18),
        Text('Frecvență', style: _section(theme)),
        const SizedBox(height: 8),
        Container(
          height: 170,
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: WingmanColors.line),
            borderRadius: BorderRadius.circular(14),
          ),
          child: stats.series.isEmpty
              ? const Center(child: Text('Fără date în perioada aleasă.'))
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      for (final point in stats.series)
                        _Bar(
                          point: point,
                          max: maxSeries,
                          width: stats.series.length > 20 ? 22 : 36,
                        ),
                    ],
                  ),
                ),
        ),
        const SizedBox(height: 18),
        Text('Ce probleme apar', style: _section(theme)),
        const SizedBox(height: 8),
        if (stats.byCode.isEmpty)
          const Text('Fără incidente în perioada aleasă.')
        else
          for (final item in stats.byCode.take(10))
            _CodeRow(item: item, max: maxCode),
        const SizedBox(height: 16),
        Text('Departamente implicate', style: _section(theme)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: <Widget>[
            for (final item in stats.byDepartment)
              Chip(
                label: Text(
                  '${_departmentLabel(item.department)} · ${item.count}',
                  style: const TextStyle(fontSize: 11),
                ),
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'Actualizat: ${stats.period}',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }

  TextStyle? _section(ThemeData theme) =>
      theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800);

  String _departmentLabel(String wire) {
    final department = Department.tryFromWire(wire);
    return department?.labelRo ?? wire;
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 86,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: WingmanColors.line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: <Widget>[
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: WingmanColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.point, required this.max, required this.width});
  final SeriesPoint point;
  final int max;
  final double width;

  @override
  Widget build(BuildContext context) {
    final fraction = max == 0 ? 0.0 : point.count / max;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          Text(
            '${point.count}',
            style: const TextStyle(fontSize: 8, color: WingmanColors.muted),
          ),
          const SizedBox(height: 2),
          Container(
            width: width,
            height: 8 + 80 * fraction,
            decoration: BoxDecoration(
              color: WingmanColors.seed,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: width + 6,
            child: Text(
              point.label,
              maxLines: 1,
              overflow: TextOverflow.clip,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 7, color: WingmanColors.muted),
            ),
          ),
        ],
      ),
    );
  }
}

class _CodeRow extends StatelessWidget {
  const _CodeRow({required this.item, required this.max});
  final CodeStat item;
  final int max;

  @override
  Widget build(BuildContext context) {
    final fraction = max == 0 ? 0.0 : item.count / max;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              SizedBox(
                width: 58,
                child: Text(
                  item.code,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: WingmanColors.navy,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  item.labelRo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11),
                ),
              ),
              Text(
                '${item.count}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 5,
              backgroundColor: WingmanColors.surfaceMuted,
              color: WingmanColors.navy,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(30),
      child: Column(
        children: <Widget>[
          const Icon(Icons.cloud_off, size: 42, color: WingmanColors.muted),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 10),
          OutlinedButton(onPressed: onRetry, child: const Text('Reîncearcă')),
        ],
      ),
    );
  }
}
