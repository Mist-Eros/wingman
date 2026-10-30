// Reporter screen — OWNER: Friend 1 (lib/features/reporter/).
//
// FROZEN CONTRACT with main.dart: class `ReporterScreen`, const constructor,
// no required arguments, dependencies only through CoreScope.
//
// Flow: the reporter speaks FIRST ("am o pată de ulei lângă poarta 12"); the
// phone records, Whisper (on the laptop) transcribes, Ollama classifies via
// POST /api/analyze. If the server says slots are missing, the app asks ONLY
// for those (spoken + on screen) and the reporter answers out loud. Then a
// confirmation screen: tap a word to correct it, or "Reia de la capăt" to
// record everything again. The 14-button menu is always available.

import 'package:flutter/material.dart';

import '../../core/core_scope.dart';
import '../../core/incidents/taxonomy.dart';
import 'reporter_controller.dart';
import 'reporter_dialogs.dart';
import 'reporter_language.dart';
import 'reporter_widgets.dart';
import 'services/location_service.dart';
import 'services/speech_service.dart';
import 'services/tts_service.dart';
import 'services/whisper_transcriber.dart';
import 'type_picker_page.dart';

class ReporterScreen extends StatefulWidget {
  const ReporterScreen({super.key, @visibleForTesting this.controller});

  /// Tests inject a controller with fake services; the app leaves it null.
  final ReporterController? controller;

  @override
  State<ReporterScreen> createState() => _ReporterScreenState();
}

class _ReporterScreenState extends State<ReporterScreen> {
  ReporterController? _controller;
  bool _ownsController = false;
  final GlobalKey _micKey = GlobalKey(debugLabel: 'reporter-mic');

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller != null) return;
    final injected = widget.controller;
    if (injected != null) {
      _controller = injected;
      return;
    }
    final api = CoreScope.apiOf(context);
    final session = CoreScope.sessionOf(context);
    final transcriber = WhisperTranscriber(api);
    _ownsController = true;
    _controller = ReporterController(
      speech: WhisperSpeechService(transcribe: transcriber.transcribe),
      tts: FlutterTtsService(),
      analyze: api.analyze,
      report: api.report,
      reporterId: session.userId,
      reporterName: session.displayName,
      location: GeolocatorLocationService(),
    );
  }

  @override
  void dispose() {
    if (_ownsController) _controller?.dispose();
    super.dispose();
  }

  // ── actions ───────────────────────────────────────────────────────────────

  /// Full menu report (idle / asking): pick a type, optional place, send.
  Future<void> _menuReport(ReporterController c) async {
    final tr = Tr(c.language);
    await c.cancelCapture();
    if (!mounted) return;
    final type = await Navigator.of(context).push<IncidentType>(
      MaterialPageRoute<IncidentType>(
        builder: (_) => TypePickerPage(language: c.language),
      ),
    );
    if (type == null || !mounted) return;
    final place = await showLocationSheet(context, tr, type.labelRo);
    if (place == null || !mounted) return;
    await c.submitMenu(type, locationText: place);
  }

  /// Menu used to override the type while confirming.
  Future<void> _pickType(ReporterController c) async {
    final type = await Navigator.of(context).push<IncidentType>(
      MaterialPageRoute<IncidentType>(
        builder: (_) => TypePickerPage(language: c.language),
      ),
    );
    if (type == null || !mounted) return;
    c.pickType(type);
  }

  Future<void> _typeInstead(ReporterController c) async {
    final tr = Tr(c.language);
    await c.cancelCapture();
    if (!mounted) return;
    final text = await showTypeTextDialog(context, tr);
    if (text == null || text.isEmpty) return;
    c.submitText(text);
  }

  Future<void> _editWord(ReporterController c, int index) async {
    final words = c.words;
    if (index < 0 || index >= words.length) return;
    final replacement =
        await showEditWordDialog(context, Tr(c.language), words[index]);
    if (replacement == null) return;
    c.editWord(index, replacement);
  }

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final c = _controller!;
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final tr = Tr(c.language);
        return Scaffold(
          appBar: AppBar(
            // Short title: the S24 Ultra header also holds the language toggle
            // and sign-out, so the long "Raportare incident" gets truncated.
            title: Text(tr('Raportare', 'Report')),
            actions: <Widget>[
              _LanguageToggle(controller: c),
              IconButton(
                tooltip: tr('Ieși din rol', 'Leave role'),
                icon: const Icon(Icons.logout),
                onPressed: () => CoreScope.maybeOf(context)?.onSignOut(),
              ),
            ],
          ),
          body: SafeArea(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: KeyedSubtree(
                // idle / listening / asking share ONE key: no rebuild of the
                // mic button while the finger is still down.
                key: ValueKey<String>(_viewId(c.phase)),
                child: _body(context, c, tr),
              ),
            ),
          ),
        );
      },
    );
  }

  String _viewId(ReporterPhase phase) {
    switch (phase) {
      case ReporterPhase.idle:
      case ReporterPhase.listening:
      case ReporterPhase.asking:
        return 'capture';
      default:
        return phase.name;
    }
  }

  Widget _body(BuildContext context, ReporterController c, Tr tr) {
    switch (c.phase) {
      case ReporterPhase.idle:
      case ReporterPhase.listening:
      case ReporterPhase.asking:
        return _capture(c, tr);
      case ReporterPhase.transcribing:
        return _busy(
          c,
          tr('Whisper transcrie…', 'Whisper is transcribing…'),
        );
      case ReporterPhase.analyzing:
        return _busy(c, tr('AI analizează…', 'AI is analysing…'));
      case ReporterPhase.submitting:
        return _busy(c, tr('Se trimite raportul…', 'Sending the report…'));
      case ReporterPhase.confirming:
        return _confirming(c, tr);
      case ReporterPhase.sent:
        return _sent(c, tr);
    }
  }

  /// ONE screen for "ready", "recording" and "waiting for my answer", so the
  /// very same MicButton stays under the finger from press to release
  /// (a different widget tree would swallow the release).
  Widget _capture(ReporterController c, Tr tr) {
    final listening = c.phase == ReporterPhase.listening;
    final question = c.question;
    final asking = question != null;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: <Widget>[
        if (c.error != null && !listening)
          ErrorBanner(message: errorMessage(c, tr)),
        if (asking) ...<Widget>[
          QuestionCard(text: question),
          if (c.transcript.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              c.transcript,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ] else ...<Widget>[
          const SizedBox(height: 12),
          Text(
            tr('Spune ce s-a întâmplat', 'Say what happened'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 4),
          Text(
            tr('Ex.: „Am o pată de ulei lângă poarta 12”',
                'E.g. "There is an oil spill near gate 12"'),
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: 12),
        Center(
          child: MicButton(
            key: _micKey,
            listening: listening,
            level: c.level,
            label: tr('Ține apăsat ca să vorbești', 'Hold to talk'),
            onPressStart: c.micDown,
            onPressEnd: c.micUp,
          ),
        ),
        Text(
          listening
              ? tr('Te ascult… eliberează când ai terminat.',
                  'Listening… release when you are done.')
              : asking
                  ? tr('Ține apăsat microfonul și răspunde.',
                      'Hold the microphone and answer.')
                  : tr('Ține apăsat microfonul cât vorbești.',
                      'Hold the microphone while you speak.'),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 16),
        if (asking) ...<Widget>[
          FilledButton.tonal(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            onPressed: listening ? null : c.skipQuestions,
            child: Text(tr('Trimite oricum', 'Send anyway')),
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Expanded(
                child: TextButton.icon(
                  icon: const Icon(Icons.apps),
                  label: Text(tr('Meniu', 'Menu')),
                  onPressed: listening ? null : () => _menuReport(c),
                ),
              ),
              Expanded(
                child: TextButton.icon(
                  icon: const Icon(Icons.keyboard),
                  label: Text(tr('Scrie', 'Type')),
                  onPressed: listening ? null : () => _typeInstead(c),
                ),
              ),
            ],
          ),
        ] else ...<Widget>[
          FilledButton.tonalIcon(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
            ),
            icon: const Icon(Icons.apps),
            label: Text(tr('Nu pot vorbi — meniu', "Can't talk — menu")),
            onPressed: listening ? null : () => _menuReport(c),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            icon: const Icon(Icons.keyboard),
            label: Text(tr('Scrie în loc să vorbești', 'Type instead')),
            onPressed: listening ? null : () => _typeInstead(c),
          ),
        ],
      ],
    );
  }

  Widget _busy(ReporterController c, String label) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
            Text(label, style: Theme.of(context).textTheme.titleMedium),
            if (c.transcript.isNotEmpty) ...<Widget>[
              const SizedBox(height: 16),
              Text(c.transcript, textAlign: TextAlign.center),
            ],
          ],
        ),
      ),
    );
  }

  Widget _confirming(ReporterController c, Tr tr) {
    final result = c.result;
    final hint = c.hintCode;
    final hintLabel =
        hint == null ? null : IncidentTaxonomy.byCode(hint)?.labelRo;
    final incomplete =
        result != null && (result.missing.isNotEmpty || result.needsMoreInfo);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: <Widget>[
        if (c.error != null) ...<Widget>[
          ErrorBanner(message: errorMessage(c, tr)),
          const SizedBox(height: 8),
        ],
        Text(
          tr('Verifică raportul', 'Check the report'),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        TranscriptChips(words: c.words, onTap: (i) => _editWord(c, i)),
        const SizedBox(height: 4),
        Text(
          tr('Atinge un cuvânt ca să-l corectezi.',
              'Tap a word to correct it.'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        if (result != null)
          UnderstoodCard(
            result: result,
            tr: tr,
            typeOverride: hintLabel,
            fix: c.fix,
            details: c.details,
          )
        else
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(tr('Nu am putut analiza textul acum.',
                      'I could not analyse the text right now.')),
                  const SizedBox(height: 8),
                  FilledButton.tonal(
                    onPressed: c.retryAnalyze,
                    child: Text(tr('Reîncearcă', 'Try again')),
                  ),
                ],
              ),
            ),
          ),
        if (incomplete) ...<Widget>[
          const SizedBox(height: 8),
          Text(
            tr('Raport incomplet: dispecerul îl verifică înainte de trimitere.',
                'Incomplete report: the dispatcher reviews it first.'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        const SizedBox(height: 16),
        Row(
          children: <Widget>[
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                ),
                icon: const Icon(Icons.replay),
                label: Text(tr('Reia de la capăt', 'Start over')),
                onPressed: c.restart,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                ),
                icon: const Icon(Icons.send),
                label: Text(tr('Trimite', 'Send')),
                onPressed: c.submit,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          icon: const Icon(Icons.apps),
          label:
              Text(tr('Schimbă tipul din meniu', 'Change the type from menu')),
          onPressed: () => _pickType(c),
        ),
      ],
    );
  }

  Widget _sent(ReporterController c, Tr tr) {
    final ticket = c.sentTicket;
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.check_circle, size: 96, color: scheme.primary),
            const SizedBox(height: 12),
            Text(
              tr('Raport trimis', 'Report sent'),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            if (ticket != null) ...<Widget>[
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(ticket.labelRo,
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 6),
                      Text(
                          '${tr('Stare', 'Status')}: ${ticket.status.labelRo}'),
                      Text(
                          '${tr('Locație', 'Location')}: ${ticket.location.display}'),
                      Text(
                          '${tr('Echipe', 'Teams')}: ${ticket.departmentsLabel}'),
                      if (ticket.isPendingOverride) ...<Widget>[
                        const SizedBox(height: 6),
                        Text(
                          tr('Dispecerul verifică în câteva secunde.',
                              'The dispatcher is reviewing it for a few seconds.'),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size(220, 56),
              ),
              icon: const Icon(Icons.add),
              label: Text(tr('Raport nou', 'New report')),
              onPressed: c.newReport,
            ),
          ],
        ),
      ),
    );
  }
}

class _LanguageToggle extends StatelessWidget {
  const _LanguageToggle({required this.controller});

  final ReporterController controller;

  @override
  Widget build(BuildContext context) {
    final listening = controller.phase == ReporterPhase.listening;
    return SegmentedButton<ReporterLanguage>(
      showSelectedIcon: false,
      style: const ButtonStyle(visualDensity: VisualDensity.compact),
      segments: <ButtonSegment<ReporterLanguage>>[
        for (final language in ReporterLanguage.values)
          ButtonSegment<ReporterLanguage>(
            value: language,
            label: Text(language.label),
          ),
      ],
      selected: <ReporterLanguage>{controller.language},
      onSelectionChanged: listening
          ? null
          : (selection) => controller.setLanguage(selection.first),
    );
  }
}
