import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/models/ticket.dart';
import 'dispatcher_dialogs.dart';
import 'ticket_feed_card.dart';
import 'urgency_style.dart';

/// Top-priority card for the 5-second dispatcher override window.
class OverrideCountdownCard extends StatefulWidget {
  const OverrideCountdownCard({
    super.key,
    required this.ticket,
    required this.busy,
    required this.onConfirm,
    required this.onDeny,
    required this.onReclassify,
    this.selected = false,
    this.onSelect,
    this.demoMode = false,
  });

  final Ticket ticket;
  final bool busy;
  final Future<void> Function() onConfirm;
  final Future<void> Function(String reason) onDeny;
  final Future<void> Function(ReclassifyChoice choice) onReclassify;
  final bool selected;
  final VoidCallback? onSelect;
  final bool demoMode;

  @override
  State<OverrideCountdownCard> createState() => _OverrideCountdownCardState();
}

class _OverrideCountdownCardState extends State<OverrideCountdownCard> {
  Timer? _ticker;
  int _secondsLeft = 0;

  @override
  void initState() {
    super.initState();
    _secondsLeft = widget.ticket.remainingOverrideSeconds();
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (!mounted) return;
      final next = widget.ticket.remainingOverrideSeconds();
      if (next != _secondsLeft) {
        setState(() => _secondsLeft = next);
      }
    });
  }

  @override
  void didUpdateWidget(covariant OverrideCountdownCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ticket.id != widget.ticket.id ||
        oldWidget.ticket.overrideDeadline != widget.ticket.overrideDeadline ||
        oldWidget.ticket.version != widget.ticket.version) {
      _secondsLeft = widget.ticket.remainingOverrideSeconds();
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _deny() async {
    final reason = await showDenyReasonDialog(context);
    if (reason == null || !mounted) return;
    await widget.onDeny(reason);
  }

  Future<void> _reclassify() async {
    final choice = await showReclassifyDialog(context);
    if (choice == null || !mounted) return;
    await widget.onReclassify(choice);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = UrgencyStyle.of(widget.ticket.urgency);
    final progress = (_secondsLeft / 5.0).clamp(0.0, 1.0);
    final expired = _secondsLeft <= 0;

    return Material(
      color: style.fillStrong,
      elevation: widget.selected ? 3 : 1,
      shadowColor: style.accent.withValues(alpha: 0.35),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: widget.selected ? style.accent : const Color(0xFFD92D20),
          width: widget.selected ? 2.5 : 2,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: widget.onSelect,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD92D20),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'CONFIRMĂ ACUM',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      expired
                          ? 'Fereastră expirată — auto-dispecerizare'
                          : 'Ai $_secondsLeft s să confirmi, respingi sau reclasifici',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: const Color(0xFF7A271A),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: Stack(
                      alignment: Alignment.center,
                      children: <Widget>[
                        CircularProgressIndicator(
                          value: expired ? 0 : progress,
                          strokeWidth: 4,
                          color: const Color(0xFFD92D20),
                          backgroundColor:
                              const Color(0xFFD92D20).withValues(alpha: 0.15),
                        ),
                        Text(
                          '$_secondsLeft',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFFD92D20),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: expired ? 0 : progress,
                  minHeight: 5,
                  color: const Color(0xFFD92D20),
                  backgroundColor:
                      const Color(0xFFD92D20).withValues(alpha: 0.12),
                ),
              ),
              const SizedBox(height: 12),
              TicketCardBody(ticket: widget.ticket, compact: true),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: <Widget>[
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF027A48),
                      minimumSize: const Size(120, 44),
                    ),
                    onPressed: widget.busy || expired ? null : widget.onConfirm,
                    icon: widget.busy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check_circle_outline),
                    label: const Text('Confirmă'),
                  ),
                  FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(120, 44),
                    ),
                    onPressed: widget.busy || expired ? null : _deny,
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('Respinge'),
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(120, 44),
                      foregroundColor: style.onFill,
                    ),
                    onPressed: widget.busy || expired ? null : _reclassify,
                    icon: const Icon(Icons.swap_horiz),
                    label: const Text('Reclasifică'),
                  ),
                ],
              ),
              if (widget.demoMode) ...[
                const SizedBox(height: 8),
                Text(
                  'Mod local — acțiunile actualizează doar lista locală',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: style.onFill.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
