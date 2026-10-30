// The reporter's "brain": decides what is still unknown, asks for it ONCE,
// and merges what the server understood with what was understood locally.
//
// Rules (the whole point):
//   1. Ask only for what is MISSING — if the reporter already said it
//      (even inside the first sentence), do not ask.
//   2. Never ask the same thing twice. Whatever the reporter answers to a
//      question is recorded, even when it cannot be parsed or matched to the
//      taxonomy ("o pată verde ciudată" stays exactly as said).
//   3. No predefined problem: when the type is unknown, ASK the type
//      ("scurgere, securitate, defecțiune…") and keep the answer; a category
//      word is enough.
//   4. Follow-ups depend on the problem: a spill → how big; fire/smoke or a
//      stuck lift → is anyone in danger; unauthorized access → how many.
//   5. At most [maxQuestions] questions per report; then the report goes on
//      (the dispatcher reviews incomplete ones).
//
// The server stays the classifier of record (Ollama via /api/analyze); this
// brain works with or without it, so questions keep flowing even if the
// server is slow or down.

import '../../../core/incidents/taxonomy.dart';
import '../../../core/models/analyze_result.dart';
import '../../../core/models/ticket.dart';
import 'severity.dart';
import 'text_utils.dart';
import 'understanding.dart';

/// One thing the reporter said, and the question it answered (if any).
class BrainTurn {
  const BrainTurn({required this.slot, required this.text});

  /// null for free speech; otherwise the slot of the question it answers.
  final String? slot;
  final String text;
}

class PlannedQuestion {
  const PlannedQuestion(
      {required this.slot, required this.ro, required this.en});

  /// 'type' | 'location' | 'size' | 'people' | 'count' | 'server'
  final String slot;
  final String ro;
  final String en;

  /// Server-provided questions only exist in Romanian.
  bool get isRomanianOnly => ro == en;
}

class Assessment {
  const Assessment({
    required this.result,
    required this.next,
    required this.details,
  });

  /// Fields merged from the server and the local understanding.
  final AnalyzeResult result;

  /// The next question, or null when nothing more should be asked.
  final PlannedQuestion? next;

  /// Detail slot → what the reporter said (size, people, count), in order.
  final Map<String, String> details;
}

/// Follow-up details worth asking, per incident type.
///
/// Deliberately no "people in danger" slot: a critical incident is dispatched
/// immediately (firefighters/security/etc. get it) and the dispatcher decides.
/// Blocking a report to ask "is anyone hurt?" is bad in an emergency — that was
/// the "o pisică a luat foc" bug (a burning cat, and the app asked about
/// injured people). Size/count stay for the low-stakes offline path.
const Map<String, List<String>> kDetailSlots = <String, List<String>>{
  'SF-SPILL': <String>['size'],
  'SF-FOD': <String>['size'],
  'SC-ACCESS': <String>['count'],
};

/// Romanian label (it goes to dispatchers) and English label of a slot.
String detailLabel(String slot, {required bool ro}) {
  switch (slot) {
    case 'size':
      return ro ? 'Dimensiune' : 'Size';
    case 'people':
      return ro ? 'Persoane în pericol' : 'People in danger';
    case 'count':
      return ro ? 'Persoane implicate' : 'People involved';
    default:
      return ro ? 'Detaliu' : 'Detail';
  }
}

class ConversationBrain {
  ConversationBrain();

  final Set<String> _asked = <String>{};

  /// How many questions were asked so far (sent to the server as
  /// `clarifications_asked`).
  int get askedCount => _asked.length;

  void reset() => _asked.clear();

  /// Remember that [slot] was asked, so it is never asked again.
  void markAsked(String slot) => _asked.add(slot);

  Assessment assess({
    required List<BrainTurn> turns,
    required AnalyzeResult? server,
    String? hintCode,
    int maxQuestions = 3,
    bool english = false,
  }) {
    final spoken = turns.map((turn) => turn.text).join(' ');
    final heard = understand(spoken);

    // ── type ────────────────────────────────────────────────────────────────
    final serverCode = server?.fields.incidentCode;
    final IncidentType? type =
        (hintCode != null ? IncidentTaxonomy.byCode(hintCode) : null) ??
            (serverCode != null ? IncidentTaxonomy.byCode(serverCode) : null) ??
            heard.type;
    final category = type?.category ?? heard.category;
    final typeAnswer = _answerOf(turns, 'type');

    // ── location ────────────────────────────────────────────────────────────
    final serverLocation = server?.fields.location ?? '';
    final locationAnswer = _answerOf(turns, 'location');
    final location = serverLocation.isNotEmpty
        ? serverLocation
        : heard.location.isNotEmpty
            ? heard.location
            : (locationAnswer == null ? '' : _shorten(locationAnswer));

    // ── details (only the ones that matter for this type) ───────────────────
    final slotsForType = type == null
        ? const <String>[]
        : (kDetailSlots[type.code] ?? const <String>[]);
    final details = <String, String>{};
    for (final slot in slotsForType) {
      final value = _detailValue(slot, heard, _answerOf(turns, slot));
      if (value != null) details[slot] = value;
    }

    // ── urgency: the type's table value is the floor; what was said raises it
    final fromServer = serverCode != null && hintCode == null;
    final peopleSaid = details['people'] ?? heard.people;
    final peopleInDanger =
        peopleSaid == 'Da' || server?.fields.peopleAtRisk == true;
    final sizeMatters = type == null || kSizeMatters.contains(type.code);
    final Urgency floor = fromServer
        ? Urgency.max(server!.fields.urgency, type?.urgency ?? Urgency.low)
        : (type?.urgency ?? _categoryFloor(category));
    final severity = assessSeverity(
      floor: floor,
      signals: type != null && kFellMeansBroken.contains(type.code)
          ? heard.signals.copyWith(fell: false)
          : heard.signals,
      peopleInDanger: peopleInDanger,
      sizeLevel: sizeMatters ? sizeLevelOf(details['size'] ?? heard.size) : 0,
      sizeMatters: sizeMatters,
    );

    // ── confidence ──────────────────────────────────────────────────────────
    final locationKnown = location.isNotEmpty;
    final typeFromAnswer = typeAnswer != null &&
        type != null &&
        understand(typeAnswer).type?.code == type.code;
    final ConfidenceResult? local = (hintCode != null || fromServer)
        ? null
        : computeConfidence(ConfidenceInput(
            hasType: type != null,
            hasCategory: category != null,
            typeScore: heard.typeScore,
            runnerUpScore: heard.runnerUpScore,
            typeFromAnswer: typeFromAnswer,
            locationKnown: locationKnown,
            detailsKnown: details.length,
            detailsNeeded: slotsForType.length,
          ));
    final double confidence = hintCode != null
        ? 1.0
        : fromServer
            ? server!.fields.confidence
            : local!.value;

    // ── merged result for the confirmation card ─────────────────────────────
    final fields = AnalyzeFields(
      incidentCode: type?.code,
      labelRo: type?.labelRo ??
          category?.labelRo ??
          (typeAnswer == null ? null : '„${_shorten(typeAnswer)}”'),
      location: location,
      peopleAtRisk: server?.fields.peopleAtRisk ??
          (peopleSaid == null ? null : peopleSaid == 'Da'),
      urgency: severity.urgency,
      confidence: confidence,
      aiSource: hintCode != null
          ? AiSource.manual
          : (server?.fields.aiSource ?? AiSource.fallback),
      rationale: _rationale(
        english: english,
        severity: severity,
        local: local,
        confidence: confidence,
        serverRationale: fromServer ? server!.fields.rationale : null,
        manual: hintCode != null,
      ),
    );

    final missing = <String>[
      if (type == null && category == null) 'incident_code',
      if (location.isEmpty) 'location',
    ];

    // ── what to ask next ─────────────────────────────────────────────────────
    // The server owns the conversation when it actually knows something: it
    // classified the incident or it explicitly asks for a slot. If it says the
    // report is ready, everything it could extract is already in (`o femeie a
    // luat foc la poarta 2` → type + location + people_at_risk) and the local
    // brain must NOT invent extra "detail" questions. A dumb/empty server
    // answer (no code, no question) falls back to the local brain as before.
    final serverAuthoritative = server != null &&
        (server.fields.incidentCode != null || server.needsMoreInfo);
    PlannedQuestion? next;
    if (serverAuthoritative) {
      if (!server.ready && _asked.length < maxQuestions) {
        next = _plannedFromServer(server, type);
      }
    } else {
      // Offline / server could not classify: the local brain fills the gaps.
      final candidates = <PlannedQuestion>[];
      if (type == null && category == null) candidates.add(_typeQuestion());
      if (location.isEmpty) candidates.add(_locationQuestion());
      for (final slot in slotsForType) {
        if (!details.containsKey(slot)) {
          candidates.add(_detailQuestion(slot, type));
        }
      }
      if (_asked.length < maxQuestions) {
        for (final candidate in candidates) {
          if (!_asked.contains(candidate.slot)) {
            next = candidate;
            break;
          }
        }
      }
    }
    if (next != null && _asked.contains(next.slot)) next = null;

    return Assessment(
      result: AnalyzeResult(
        fields: fields,
        missing: List<String>.unmodifiable(missing),
        question: null,
        clarificationsAsked: _asked.length,
        maxClarifications: maxQuestions,
        ready: next == null,
        taxonomyVersion: server?.taxonomyVersion,
      ),
      next: next,
      details: details,
    );
  }

  // ── questions ─────────────────────────────────────────────────────────────

  PlannedQuestion _typeQuestion() => const PlannedQuestion(
        slot: 'type',
        ro: 'Ce tip de problemă este? De exemplu: scurgere, securitate, '
            'defecțiune sau operațiuni.',
        en: 'What kind of problem is it? For example: a leak, security, a '
            'breakdown or operations.',
      );

  PlannedQuestion _locationQuestion() => const PlannedQuestion(
        slot: 'location',
        ro: 'Unde se află? Spune poarta, sectorul, terminalul sau zona.',
        en: 'Where is it? Say the gate, sector, terminal or area.',
      );

  PlannedQuestion _detailQuestion(String slot, IncidentType? type) {
    switch (slot) {
      case 'size':
        if (type?.code == 'SF-FOD') {
          return const PlannedQuestion(
            slot: 'size',
            ro: 'Cât de mare este obiectul?',
            en: 'How big is the object?',
          );
        }
        return const PlannedQuestion(
          slot: 'size',
          ro: 'Cât de mare este pata? Mică, medie sau mare?',
          en: 'How big is the spill? Small, medium or large?',
        );
      case 'count':
        return const PlannedQuestion(
          slot: 'count',
          ro: 'Câte persoane sunt implicate?',
          en: 'How many people are involved?',
        );
      default:
        return const PlannedQuestion(
          slot: 'people',
          ro: 'Este cineva în pericol, blocat sau rănit?',
          en: 'Is anyone in danger, trapped or injured?',
        );
    }
  }

  /// A question only the server knows to ask (anything that is not the type,
  /// the place or the "anyone in danger" question we already cover).
  PlannedQuestion? _unmappedServerQuestion(AnalyzeResult? server) {
    final question = server?.question;
    if (server == null || question == null || question.isEmpty) return null;
    if (server.asksForLocation || server.asksForType) return null;
    if (normalizeText(question).contains('pericol')) return null;
    return PlannedQuestion(slot: 'server', ro: question, en: question);
  }

  /// Maps the server's Romanian question to the matching planned question, so
  /// the app asks exactly what the server wants and nothing more.
  PlannedQuestion? _plannedFromServer(
      AnalyzeResult server, IncidentType? type) {
    final question = server.question;
    if (question == null || question.isEmpty) return null;
    if (server.asksForLocation) return _locationQuestion();
    if (server.asksForType) return _typeQuestion();
    // Policy: never block an urgent report on "is anyone in danger?" — the
    // incident is dispatched anyway and the dispatcher can reclassify/deny in
    // the 5-second window. (Cats/dogs/objects cannot answer it either.)
    if (normalizeText(question).contains('pericol')) return null;
    return _unmappedServerQuestion(server) ??
        PlannedQuestion(slot: 'server', ro: question, en: question);
  }

  // ── helpers ───────────────────────────────────────────────────────────────

  /// Floor for an incident whose exact type is unknown: safety and security
  /// problems start high, the rest medium (never "low" for the unknown).
  Urgency _categoryFloor(IncidentCategory? category) {
    switch (category) {
      case IncidentCategory.safetyFire:
      case IncidentCategory.security:
        return Urgency.high;
      case IncidentCategory.maintenance:
      case IncidentCategory.operations:
      case null:
        return Urgency.medium;
    }
  }

  /// One readable sentence: why this urgency, why this confidence.
  String _rationale({
    required bool english,
    required Severity severity,
    required ConfidenceResult? local,
    required double confidence,
    required String? serverRationale,
    required bool manual,
  }) {
    final level = _urgencyWord(severity.urgency, english);
    final why = severity.reasons
        .map((key) => reasonText(key, english: english))
        .join(', ');
    final urgencyPart = severity.reasons.isEmpty
        ? (english
            ? 'Urgency $level (default for this type)'
            : 'Urgență $level (implicită pentru tip)')
        : (english ? 'Urgency $level: $why' : 'Urgență $level: $why');
    if (manual) {
      return english
          ? '$urgencyPart. Type picked by you.'
          : '$urgencyPart. Tip ales de tine.';
    }
    final percent = (confidence * 100).round();
    final String confidencePart;
    if (local != null) {
      final notes = local.notes
          .map((key) => confidenceNoteText(key, english: english))
          .join(', ');
      confidencePart = english
          ? 'Confidence $percent% (estimated: $notes)'
          : 'Încredere $percent% (estimat: $notes)';
    } else {
      confidencePart = english
          ? 'Confidence $percent% (from the AI server)'
          : 'Încredere $percent% (de la serverul AI)';
    }
    final base = serverRationale == null || serverRationale.isEmpty
        ? ''
        : '$serverRationale. ';
    final text = '$base$urgencyPart. $confidencePart.';
    return text.length <= 200 ? text : '${text.substring(0, 197)}…';
  }

  String _urgencyWord(Urgency urgency, bool english) {
    if (!english) return urgency.labelRo.toLowerCase();
    switch (urgency) {
      case Urgency.low:
        return 'low';
      case Urgency.medium:
        return 'medium';
      case Urgency.high:
        return 'high';
      case Urgency.critical:
        return 'critical';
    }
  }

  String? _answerOf(List<BrainTurn> turns, String slot) {
    final answers = turns
        .where((turn) => turn.slot == slot && turn.text.trim().isNotEmpty)
        .map((turn) => turn.text.trim())
        .toList();
    return answers.isEmpty ? null : answers.join(' ');
  }

  /// What was said about [slot]: first what we could parse from the whole
  /// conversation, otherwise the raw answer to that very question.
  String? _detailValue(String slot, Understanding heard, String? answer) {
    switch (slot) {
      case 'size':
        return heard.size ?? (answer == null ? null : _shorten(answer));
      case 'count':
        return heard.count ?? (answer == null ? null : _shorten(answer));
      case 'people':
        return heard.people ??
            (answer == null
                ? null
                : (yesNoFromAnswer(answer) ?? _shorten(answer)));
    }
    return null;
  }

  String _shorten(String text) {
    final clean = text.trim().replaceAll(RegExp(r'[\s]+'), ' ');
    final stripped = clean.replaceAll(RegExp(r'[.!?…]+$'), '');
    return stripped.length <= 60 ? stripped : '${stripped.substring(0, 57)}…';
  }
}
