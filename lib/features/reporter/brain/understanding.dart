// Understands what the reporter has said so far (RO + EN, with or without
// diacritics, with number words): which incident type, where, how big, who is
// in danger. Pure functions — no server, no state.

import '../../../core/incidents/taxonomy.dart';
import 'lexicon.dart';
import 'severity.dart';
import 'text_utils.dart';

class Understanding {
  const Understanding({
    this.type,
    this.category,
    this.location = '',
    this.size,
    this.people,
    this.count,
    this.typeScore = 0,
    this.runnerUpScore = 0,
    this.signals = const Signals(),
  });

  /// Keyword score of [type] and of the second best candidate (evidence for
  /// the confidence).
  final int typeScore;
  final int runnerUpScore;

  /// Danger signals in the text (they raise the urgency).
  final Signals signals;

  /// Best matching taxonomy type, or null when unknown / ambiguous.
  final IncidentType? type;

  /// Category when the type is unknown but the category is ("securitate").
  final IncidentCategory? category;

  /// "Poarta 12", "Pistă", ... or '' when no place was mentioned.
  final String location;

  /// The reporter's own words about the size ("foarte mare", "2 m", "cât o farfurie").
  final String? size;

  /// "Da" / "Nu" when it was said whether someone is in danger, else null.
  final String? people;

  /// How many people ("3 persoane"), else null.
  final String? count;

  IncidentCategory? get anyCategory => type?.category ?? category;
}

Understanding understand(String text) {
  final norm = normalizeText(text);
  final guess = _guessType(norm);
  return Understanding(
    type: guess.type,
    category: guess.type == null ? _guessCategory(norm) : null,
    location: _findLocation(norm),
    size: _findSize(text, norm),
    people: _findPeople(norm),
    count: _findCount(text, norm),
    typeScore: guess.score,
    runnerUpScore: guess.runnerUp,
    signals: findSignals(norm),
  );
}

// ── type ────────────────────────────────────────────────────────────────────

({IncidentType? type, int score, int runnerUp}) _guessType(String norm) {
  const none = (type: null, score: 0, runnerUp: 0);
  if (norm.trim().isEmpty) return none;
  final tokens = tokensOf(norm);
  final padded = ' $norm ';
  final scores = <String, int>{};
  for (final entry in kTypeStems.entries) {
    var score = 0;
    for (final stem in entry.value) {
      if (stemMatches(stem.stem, tokens, padded)) score += stem.weight;
    }
    if (score > 0) scores[entry.key] = score;
  }
  if (scores.isEmpty) return none;
  final ranked = scores.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  final runnerUp = ranked.length > 1 ? ranked[1].value : 0;
  if (ranked.length > 1 && ranked[0].value == runnerUp) {
    // Tie: only accept it when both candidates agree on the category.
    final first = IncidentTaxonomy.byCode(ranked[0].key);
    final second = IncidentTaxonomy.byCode(ranked[1].key);
    if (first == null || second == null || first.category != second.category) {
      return none;
    }
  }
  return (
    type: IncidentTaxonomy.byCode(ranked.first.key),
    score: ranked.first.value,
    runnerUp: runnerUp,
  );
}

IncidentCategory? _guessCategory(String norm) {
  final tokens = tokensOf(norm);
  final padded = ' $norm ';
  for (final entry in kCategoryWords.entries) {
    for (final word in entry.value) {
      if (stemMatches(word, tokens, padded)) return entry.key;
    }
  }
  return null;
}

// ── location ────────────────────────────────────────────────────────────────

const Map<String, String> _placeNouns = <String, String>{
  'poarta': 'Poarta', 'gate': 'Gate', 'stand': 'Stand', 'sectorul': 'Sector',
  'sector': 'Sector', 'terminalul': 'Terminal', 'terminal': 'Terminal',
  'zona': 'Zona', 'zone': 'Zone', 'banda': 'Banda', 'carousel': 'Carousel',
  'pista': 'Pista',
  'runway': 'Runway', 'nivel': 'Nivel', 'nivelul': 'Nivel', 'etaj': 'Etaj',
  'etajul': 'Etaj', 'floor': 'Floor', 'level': 'Level', 'ghiseul': 'Ghișeu',
  'desk': 'Desk',
};

/// Places that are a location even without a number ("pe pistă").
const Map<String, String> _placeWords = <String, String>{
  'pista': 'Pistă', 'runway': 'Runway', 'platforma': 'Platformă',
  'apron': 'Apron', 'terminal': 'Terminal', 'terminalul': 'Terminal',
  'parcare': 'Parcare', 'parcarea': 'Parcare', 'hol': 'Hol', 'holul': 'Hol',
  'intrare': 'Intrare', 'intrarea': 'Intrare', 'sosiri': 'Sosiri',
  'plecari': 'Plecări', 'arrivals': 'Arrivals', 'departures': 'Departures',
  'toaleta': 'Toaletă', 'toalete': 'Toaletă', 'restroom': 'Restroom',
  'cafenea': 'Cafenea', 'magazin': 'Magazin', 'depozit': 'Depozit',
};

final RegExp _placeWithId = RegExp(
  r'\b(poarta|gate|stand|sectorul|sector|terminalul|terminal|zona|zone|banda|'
  r'carusel\w*|carousel|pista|runway|nivelul|nivel|etajul|etaj|floor|level|'
  r'ghiseul|desk)\s+'
  // "banda de bagaje 3", "poarta de imbarcare 12", "gate for boarding 4"
  r'(?:(?:de|of|for)\s+[a-z]+\s+)?'
  r'(?:(?:nr|numarul|number|no)\s+)?'
  '([a-z]?[0-9]{1,3}[a-z]?|$kNumberWordsPattern)\\b',
);

final RegExp _gateLetter = RegExp(r'\b(poarta|gate)\s+([b-e])\b');
final RegExp _gateLetterA = RegExp(r'\b(poarta|gate)\s+a\s*$');
final RegExp _terminalCode = RegExp(r'\bt\s?([1-9])\b');

String _findLocation(String norm) {
  final withId = _placeWithId.firstMatch(norm);
  if (withId != null) {
    final found = withId.group(1)!;
    final noun = _placeNouns[found] ??
        '${found[0].toUpperCase()}${found.substring(1)}';
    final raw = withId.group(2)!;
    final id = numberFromToken(raw) ?? raw.toUpperCase();
    return '$noun $id';
  }
  final letter = _gateLetter.firstMatch(norm) ?? _gateLetterA.firstMatch(norm);
  if (letter != null) {
    final noun = _placeNouns[letter.group(1)!]!;
    final id = letter.groupCount >= 2 && letter.group(2) != null
        ? letter.group(2)!.toUpperCase()
        : 'A';
    return '$noun $id';
  }
  final terminal = _terminalCode.firstMatch(norm);
  if (terminal != null) return 'Terminal ${terminal.group(1)}';
  for (final token in tokensOf(norm)) {
    final place = _placeWords[token];
    if (place != null) return place;
  }
  return '';
}

// ── size / people / count ───────────────────────────────────────────────────

final RegExp _measure = RegExp(
  r'(\d+(?:[.,]\d+)?)\s*'
  r'(centimetri|metri patrati|metri|metru|litri|litru|meters|metres|meter|'
  r'metre|liters|litres|inches|inch|feet|foot|cm|mp|m2|ft|m|l)\b',
);
final RegExp _comparison =
    RegExp(r'\bcat\s+(?:o|un|niste)\s+[a-z]+(?:\s+[a-z]+)?');
final RegExp _comparisonEn =
    RegExp(r'\b(?:size of|as big as|about as big as)\s+(?:a|an|the)?\s*[a-z]+');
final RegExp _sizeWord = RegExp(
  r'\b(?:(?:foarte|destul de|cam|extrem de|very|quite|pretty|really)\s+)?'
  r'(mica|mic|mici|mari|mare|medie|mediu|uriasa|uriasi|imensa|imens|enorma|'
  r'enorm|minuscula|minuscul|intinsa|intins|small|big|large|medium|huge|'
  r'tiny|massive|little|giant)\b',
);

String? _findSize(String original, String norm) {
  for (final pattern in <RegExp>[
    _measure,
    _comparison,
    _comparisonEn,
    _sizeWord,
  ]) {
    final match = pattern.firstMatch(norm);
    if (match != null) {
      return original.substring(match.start, match.end).trim();
    }
  }
  return null;
}

final RegExp _peopleNo = RegExp(
  r'\b(nimeni|fara (?:victime|raniti|persoane|oameni)|nu (?:e|este|sunt) '
  r'(?:nimeni|raniti|victime|oameni|nicio persoana)|no one|nobody|'
  r'no injur\w*|nothing|not hurt)\b',
);
final RegExp _peopleYes = RegExp(
  r'\b(raniti|ranit|ranita|victime|in pericol|blocati|panica|'
  r'ambulanta|injured|hurt|danger|trapped|stuck inside|panic|casualt\w*|'
  r'(?:oameni|persoane|cineva|someone|people|person)\s+'
  r'(?:inauntru|inside|blocat\w*|prins\w*|stuck))\b',
);

// Person + harm phrasing ("o femeie a luat foc", "un copil a lesinat") already
// means someone is in danger — don't ask about it later.
final RegExp _personHarm = RegExp(
  r'\b(copil\w*|baiat\w*|fat[ae]\w*|femeie|barbat\w*|persoan\w*|pasager\w*|'
  r'angajat\w*|victim\w*|pacient\w*|cineva|om|oameni)\b.{0,70}?\b'
  r'(a luat foc|au luat foc|luat foc|in flacari|ars|arse|ranit\w*|cazut\w*|'
  r'lesinat\w*|sanger\w*|in pericol|evacuat|atacat)\b',
);

String? _findPeople(String norm) {
  if (_peopleNo.hasMatch(norm)) return 'Nu';
  if (_personHarm.hasMatch(norm)) return 'Da';
  if (_peopleYes.hasMatch(norm)) return 'Da';
  return null;
}

final RegExp _count = RegExp(
  r'\b(\d{1,3}|' + kNumberWordsPattern + r')\s+'
  r'(persoane|persoana|oameni|barbati|femei|copii|people|persons|person|men|'
  r'women|individuals|children)\b',
);

String? _findCount(String original, String norm) {
  final match = _count.firstMatch(norm);
  if (match == null) return null;
  return original.substring(match.start, match.end).trim();
}

/// "Da" / "Nu" from a free answer to a yes/no question, else null.
String? yesNoFromAnswer(String answer) {
  final norm = normalizeText(answer);
  if (_peopleYes.hasMatch(norm)) return 'Da';
  if (_peopleNo.hasMatch(norm)) return 'Nu';
  final tokens = tokensOf(norm);
  if (tokens.contains('nu') || tokens.contains('no') || tokens.contains('nope')) {
    return 'Nu';
  }
  if (tokens.contains('da') || tokens.contains('yes') || tokens.contains('yeah')) {
    return 'Da';
  }
  return null;
}
