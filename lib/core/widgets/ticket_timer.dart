import 'dart:async';

import 'package:flutter/material.dart';

import '../models/ticket.dart';

/// Human elapsed format for a live ticket: MM:SS, then H:MM:SS, then d HH:MM.
String formatTicketElapsed(Duration duration) {
  final total = duration.isNegative ? 0 : duration.inSeconds;
  final days = total ~/ Duration.secondsPerDay;
  final hours = (total % Duration.secondsPerDay) ~/ Duration.secondsPerHour;
  final minutes =
      (total % Duration.secondsPerHour) ~/ Duration.secondsPerMinute;
  final seconds = total % Duration.secondsPerMinute;
  if (days > 0) {
    return '${days}d ${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}';
  }
  if (hours > 0) {
    return '$hours:${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }
  return '${minutes.toString().padLeft(2, '0')}:'
      '${seconds.toString().padLeft(2, '0')}';
}

/// Short, readable average-handling-time label.
String formatAverageHandling(int? seconds) {
  if (seconds == null) return '—';
  final total = seconds < 0 ? 0 : seconds;
  final hours = total ~/ Duration.secondsPerHour;
  final minutes =
      (total % Duration.secondsPerHour) ~/ Duration.secondsPerMinute;
  final secs = total % Duration.secondsPerMinute;
  if (hours > 0) return '${hours}h ${minutes.toString().padLeft(2, '0')}m';
  if (minutes > 0) return '${minutes}m ${secs.toString().padLeft(2, '0')}s';
  return '${secs}s';
}

/// Live “since posted” timer for one ticket. It freezes at resolution/denial.
class TicketTimerChip extends StatefulWidget {
  const TicketTimerChip({super.key, required this.ticket});

  final Ticket ticket;

  @override
  State<TicketTimerChip> createState() => _TicketTimerChipState();
}

class _TicketTimerChipState extends State<TicketTimerChip> {
  Timer? _timer;

  bool get _frozen => widget.ticket.status.isTerminal;

  Duration get _elapsed {
    final start = widget.ticket.createdAt;
    final end = _frozen
        ? (widget.ticket.resolvedAt ?? widget.ticket.updatedAt)
        : DateTime.now().toUtc();
    final value = end.difference(start);
    return value.isNegative ? Duration.zero : value;
  }

  @override
  void initState() {
    super.initState();
    _syncTimer();
  }

  @override
  void didUpdateWidget(covariant TicketTimerChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncTimer();
  }

  void _syncTimer() {
    _timer?.cancel();
    _timer = null;
    if (_frozen) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _frozen ? const Color(0xFF64748B) : theme.colorScheme.primary;
    return Tooltip(
      message:
          _frozen ? 'Timp total până la închidere' : 'Timp de la raportare',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: color.withValues(alpha: 0.20)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.timer_outlined, size: 13, color: color),
            const SizedBox(width: 3),
            Text(
              formatTicketElapsed(_elapsed),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                fontFeatures: const <FontFeature>[
                  FontFeature.tabularFigures(),
                ],
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
