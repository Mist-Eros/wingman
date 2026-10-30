// Small presentational widgets of the reporter flow (no business logic).

import 'package:flutter/material.dart';

import '../../core/models/analyze_result.dart';
import 'brain/conversation_brain.dart' show detailLabel;
import 'reporter_controller.dart';
import 'reporter_language.dart';
import 'services/location_service.dart';

/// Big round push-to-talk microphone: HOLD to record, RELEASE to finish. The
/// outer halo grows with the input [level] while listening, so the reporter
/// sees the phone is hearing them.
///
/// Uses raw pointer events (not a tap): the release is delivered even when
/// the finger slides off the button, and a long press never opens a menu.
class MicButton extends StatelessWidget {
  const MicButton({
    super.key,
    required this.listening,
    required this.level,
    required this.onPressStart,
    required this.onPressEnd,
    required this.label,
  });

  final bool listening;
  final double level;
  final VoidCallback? onPressStart;
  final VoidCallback? onPressEnd;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = onPressStart != null;
    final color = listening ? scheme.error : scheme.primary;
    final onColor = listening ? scheme.onError : scheme.onPrimary;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      onLongPress: onPressStart,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: enabled ? (_) => onPressStart?.call() : null,
        onPointerUp: enabled ? (_) => onPressEnd?.call() : null,
        onPointerCancel: enabled ? (_) => onPressEnd?.call() : null,
        child: SizedBox(
          width: 240,
          height: 240,
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 150 + (listening ? level * 90 : 0),
                height: 150 + (listening ? level * 90 : 0),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.16),
                ),
              ),
              Material(
                color: enabled ? color : scheme.surfaceContainerHighest,
                shape: const CircleBorder(),
                elevation: listening ? 1 : 4,
                child: SizedBox(
                  width: 150,
                  height: 150,
                  child: Icon(
                    Icons.mic_rounded,
                    size: 72,
                    color: enabled ? onColor : scheme.outline,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The question the app asks (and speaks) to fill a missing slot.
class QuestionCard extends StatelessWidget {
  const QuestionCard({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: <Widget>[
            Icon(Icons.record_voice_over, color: scheme.onSecondaryContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: scheme.onSecondaryContainer,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ErrorBanner extends StatelessWidget {
  const ErrorBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: <Widget>[
            Icon(Icons.error_outline, color: scheme.onErrorContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: scheme.onErrorContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Human message for a controller error.
String errorMessage(ReporterController c, Tr tr) {
  final detail = c.errorDetail;
  switch (c.error) {
    case ReporterError.micUnavailable:
      return tr(
        'Microfonul nu e disponibil. Permite accesul la microfon sau folosește '
            'meniul / scrie textul.',
        'Microphone unavailable. Allow microphone access or use the menu / '
            'type the text.',
      );
    case ReporterError.noSpeech:
      return tr(
        'Nu am auzit nimic. Apasă microfonul și încearcă din nou.',
        'I did not hear anything. Tap the microphone and try again.',
      );
    case ReporterError.aiOffline:
      return tr(
        'Serverul AI nu răspunde acum; am înțeles local ce ai spus. '
            'Raportul se poate trimite când serverul revine.',
        'The AI server is not answering; I understood what you said locally. '
            'You can send the report once the server is back.',
      );
    case ReporterError.holdToTalk:
      return tr(
        'Ține apăsat microfonul cât vorbești și eliberează-l când ai terminat.',
        'Hold the microphone while you speak and release it when you are done.',
      );
    case ReporterError.transcribe:
    case ReporterError.server:
      return (detail == null || detail.isEmpty)
          ? tr('Ceva n-a mers. Încearcă din nou.', 'Something went wrong. Try again.')
          : detail;
    case null:
      return '';
  }
}

/// Transcript as tappable words: tap a word to correct it.
class TranscriptChips extends StatelessWidget {
  const TranscriptChips({super.key, required this.words, required this.onTap});

  final List<String> words;
  final void Function(int index) onTap;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 2,
      children: <Widget>[
        for (var i = 0; i < words.length; i++)
          ActionChip(
            label: Text(words[i], style: const TextStyle(fontSize: 17)),
            visualDensity: VisualDensity.compact,
            onPressed: () => onTap(i),
          ),
      ],
    );
  }
}

/// "What I understood" card on the confirmation screen.
class UnderstoodCard extends StatelessWidget {
  const UnderstoodCard({
    super.key,
    required this.result,
    required this.tr,
    required this.typeOverride,
    required this.fix,
    this.details = const <String, String>{},
  });

  final AnalyzeResult result;
  final Tr tr;

  /// What the reporter said about size / people / count (slot → text).
  final Map<String, String> details;

  /// Romanian label of the type the reporter picked from the menu, if any.
  final String? typeOverride;
  final LocationFix? fix;

  @override
  Widget build(BuildContext context) {
    final fields = result.fields;
    final text = Theme.of(context).textTheme;
    final typeLabel =
        typeOverride ?? fields.labelRo ?? tr('nu am înțeles tipul', 'type not understood');
    final location = fields.location.isEmpty
        ? tr('lipsește', 'missing')
        : fields.location;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(tr('Ce am înțeles', 'What I understood'), style: text.titleSmall),
            const SizedBox(height: 8),
            _Row(Icons.report_problem_outlined, tr('Tip', 'Type'),
                typeOverride == null ? typeLabel : '$typeLabel (${tr('ales de tine', 'your pick')})'),
            _Row(Icons.place_outlined, tr('Locație', 'Location'), location),
            for (final entry in details.entries)
              _Row(
                entry.key == 'size'
                    ? Icons.straighten
                    : Icons.groups_outlined,
                detailLabel(entry.key, ro: tr.language == ReporterLanguage.ro),
                entry.value,
              ),
            if (fix != null)
              _Row(Icons.my_location, tr('Poziție', 'Position'), fix!.label),
            _Row(Icons.priority_high, tr('Urgență', 'Urgency'),
                fields.urgency.labelRo),
            _Row(Icons.insights, tr('Încredere', 'Confidence'),
                fields.confidenceLabel),
            if (fields.rationale != null) ...<Widget>[
              const SizedBox(height: 4),
              Text(fields.rationale!, style: text.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.icon, this.label, this.value);

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w600)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
