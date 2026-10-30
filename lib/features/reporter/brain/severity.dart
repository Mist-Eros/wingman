// Urgency and confidence, computed from WHAT WAS SAID — not from the type
// alone — and always with an explanation the reporter can read.
//
// URGENCY
//   • The type's table value is the FLOOR (the server rule: raise, never lower).
//   • Fire / explosion / gas / lava, toxic substances and a life at risk make
//     it CRITICAL whatever the type is.
//   • Otherwise each signal adds levels on top of the floor:
//       big / huge spill or object ........ +1 / +2   (spills, FOD, fire only)
//       flammable substance (fuel, sparks)  +1
//       runway / apron / next to aircraft . +1
//       "it is spreading" ................. +1
//       "urgent / help" ................... +1
//       someone slipped or fell ........... +1
//       someone in danger ................. at least HIGH (+1 if already high)
//   • Capped at critical.
//
// CONFIDENCE (only for what the app understood by itself; when the server
// classified, its own confidence is shown instead)
//   type evidence  0.30 + 0.40·strength + 0.15·margin          (0.30 – 0.85)
//        strength = best keyword score / 6, margin = lead over the runner-up
//        no type but a category word ............ 0.35, nothing ... 0.10
//   the reporter answered "what type?" itself .... at least 0.75
//   place known +0.07 / missing −0.10
//   each follow-up detail known +0.03 / still unknown −0.03
//   clamped to 0.05 – 0.95 (1.0 is reserved for a menu pick)

import '../../../core/incidents/taxonomy.dart';
import 'lexicon.dart';
import 'text_utils.dart';

/// Danger signals found in a text.
class Signals {
  const Signals({
    this.fireExplosion = false,
    this.toxic = false,
    this.life = false,
    this.flammable = false,
    this.spreading = false,
    this.urgent = false,
    this.airside = false,
    this.aircraft = false,
    this.fell = false,
  });

  final bool fireExplosion;
  final bool toxic;
  final bool life;
  final bool flammable;
  final bool spreading;
  final bool urgent;
  final bool airside;
  final bool aircraft;
  final bool fell;

  bool get critical => fireExplosion || toxic || life;

  Signals copyWith({bool? fell}) => Signals(
        fireExplosion: fireExplosion,
        toxic: toxic,
        life: life,
        flammable: flammable,
        spreading: spreading,
        urgent: urgent,
        airside: airside,
        aircraft: aircraft,
        fell: fell ?? this.fell,
      );
}

/// "a căzut sistemul" means "the system went down", not "someone fell".
const Set<String> kFellMeansBroken = <String>{'OP-IT', 'OP-QUEUE', 'MT-BELT'};

Signals findSignals(String norm) {
  final tokens = tokensOf(norm);
  final padded = ' $norm ';
  bool has(List<String> stems) => anyStemMatches(stems, tokens, padded);
  return Signals(
    fireExplosion: has(kFireExplosionStems),
    toxic: has(kToxicStems),
    life: has(kLifeStems),
    flammable: has(kFlammableStems),
    spreading: has(kSpreadingStems),
    urgent: has(kUrgentStems),
    airside: has(kAirsideStems),
    aircraft: has(kAircraftStems),
    fell: has(kFellStems),
  );
}

// ── size ────────────────────────────────────────────────────────────────────

final RegExp _measure = RegExp(
  r'(\d+(?:[.,]\d+)?)\s*(centimetri|cm|metri patrati|mp|m2|metri|metru|meters|'
  r'metres|meter|metre|m|litri|litru|liters|litres|l|feet|foot|ft|inches|inch)\b',
);

/// 0 = small / unknown, 1 = big, 2 = huge — from the reporter's own words.
int sizeLevelOf(String? phrase) {
  if (phrase == null || phrase.trim().isEmpty) return 0;
  final norm = normalizeText(phrase);
  final tokens = tokensOf(norm);

  final measure = _measure.firstMatch(norm);
  if (measure != null) {
    final value =
        double.tryParse(measure.group(1)!.replaceAll(',', '.')) ?? 0;
    final unit = measure.group(2)!;
    double meters = value;
    switch (unit) {
      case 'cm':
      case 'centimetri':
        meters = value / 100;
      case 'ft':
      case 'feet':
      case 'foot':
        meters = value * 0.3;
      case 'inch':
      case 'inches':
        meters = value * 0.025;
      case 'litri':
      case 'litru':
      case 'liters':
      case 'litres':
      case 'l':
        return value >= 100 ? 2 : (value >= 10 ? 1 : 0);
      case 'mp':
      case 'm2':
      case 'metri patrati':
        return value >= 20 ? 2 : (value >= 5 ? 1 : 0);
    }
    return meters >= 10 ? 2 : (meters >= 3 ? 1 : 0);
  }

  const small = <String>['mica', 'mic', 'mici', 'small', 'tiny', 'little',
    'minuscula', 'minuscul'];
  const huge = <String>['uriasa', 'uriasi', 'imensa', 'imens', 'enorma',
    'enorm', 'huge', 'massive', 'giant'];
  const big = <String>['mare', 'mari', 'large', 'big', 'intinsa', 'intins'];
  const intensifiers = <String>['foarte', 'extrem', 'very', 'really'];

  if (tokens.any(small.contains)) return 0;
  if (tokens.any(huge.contains)) return 2;
  if (tokens.any(big.contains)) {
    return tokens.any(intensifiers.contains) ? 2 : 1;
  }
  return 0;
}

// ── urgency ─────────────────────────────────────────────────────────────────

/// Types where a bigger size means a bigger danger.
const Set<String> kSizeMatters = <String>{'SF-SPILL', 'SF-FOD', 'SF-FIRE'};

class Severity {
  const Severity(this.urgency, this.reasons, {required this.escalated});

  final Urgency urgency;

  /// Keys of the signals that raised it (see [reasonText]).
  final List<String> reasons;

  /// True when it ended above the type's table value.
  final bool escalated;
}

Urgency _urgencyOf(int level) => Urgency.values
    .firstWhere((urgency) => urgency.level == level.clamp(1, 4));

Severity assessSeverity({
  required Urgency floor,
  required Signals signals,
  required bool peopleInDanger,
  required int sizeLevel,
  required bool sizeMatters,
}) {
  final reasons = <String>[];
  if (signals.fireExplosion) reasons.add('fire_explosion');
  if (signals.toxic) reasons.add('toxic');
  if (signals.life) reasons.add('life');
  if (signals.critical) {
    return Severity(Urgency.critical, reasons,
        escalated: floor.level < Urgency.critical.level);
  }

  var level = floor.level;
  if (sizeMatters && sizeLevel > 0) {
    level += sizeLevel;
    reasons.add(sizeLevel >= 2 ? 'size_huge' : 'size_big');
  }
  if (signals.flammable) {
    level += 1;
    reasons.add('flammable');
  }
  if (signals.airside || signals.aircraft) {
    level += 1;
    reasons.add(signals.aircraft ? 'aircraft' : 'airside');
  }
  if (signals.spreading) {
    level += 1;
    reasons.add('spreading');
  }
  if (signals.urgent) {
    level += 1;
    reasons.add('urgent');
  }
  if (signals.fell) {
    level += 1;
    reasons.add('fell');
  }
  if (peopleInDanger) {
    level = level < Urgency.high.level ? Urgency.high.level : level + 1;
    reasons.add('people');
  }
  final urgency = _urgencyOf(level);
  return Severity(urgency, reasons, escalated: urgency.level > floor.level);
}

String reasonText(String key, {required bool english}) {
  const ro = <String, String>{
    'fire_explosion': 'pericol de foc sau explozie',
    'toxic': 'substanță periculoasă',
    'life': 'viață în pericol',
    'size_big': 'dimensiune mare',
    'size_huge': 'dimensiune foarte mare',
    'flammable': 'substanță inflamabilă',
    'airside': 'în zona operațională',
    'aircraft': 'lângă o aeronavă',
    'spreading': 'se extinde',
    'urgent': 'ai spus că e urgent',
    'fell': 'cineva a căzut',
    'people': 'cineva în pericol',
  };
  const en = <String, String>{
    'fire_explosion': 'fire or explosion hazard',
    'toxic': 'hazardous substance',
    'life': 'life at risk',
    'size_big': 'large size',
    'size_huge': 'very large size',
    'flammable': 'flammable substance',
    'airside': 'airside area',
    'aircraft': 'next to an aircraft',
    'spreading': 'it is spreading',
    'urgent': 'you said it is urgent',
    'fell': 'someone fell',
    'people': 'someone in danger',
  };
  return (english ? en : ro)[key] ?? key;
}

// ── confidence ──────────────────────────────────────────────────────────────

class ConfidenceInput {
  const ConfidenceInput({
    required this.hasType,
    required this.hasCategory,
    required this.typeScore,
    required this.runnerUpScore,
    required this.typeFromAnswer,
    required this.locationKnown,
    required this.detailsKnown,
    required this.detailsNeeded,
  });

  final bool hasType;
  final bool hasCategory;
  final int typeScore;
  final int runnerUpScore;
  final bool typeFromAnswer;
  final bool locationKnown;
  final int detailsKnown;
  final int detailsNeeded;
}

class ConfidenceResult {
  const ConfidenceResult(this.value, this.notes);

  final double value;

  /// Keys explaining the number (see [confidenceNoteText]).
  final List<String> notes;
}

ConfidenceResult computeConfidence(ConfidenceInput input) {
  final notes = <String>[];
  double value;
  if (input.hasType) {
    final strength = (input.typeScore / 6).clamp(0.0, 1.0);
    final margin = input.typeScore == 0
        ? 0.0
        : ((input.typeScore - input.runnerUpScore) / input.typeScore)
            .clamp(0.0, 1.0);
    value = 0.30 + 0.40 * strength + 0.15 * margin;
    notes.add(strength >= 0.66 && margin >= 0.5
        ? 'type_clear'
        : (strength >= 0.33 ? 'type_probable' : 'type_weak'));
    if (input.typeFromAnswer && value < 0.75) {
      value = 0.75;
      notes
        ..clear()
        ..add('type_answered');
    }
  } else if (input.hasCategory) {
    value = 0.35;
    notes.add('category_only');
  } else {
    value = 0.10;
    notes.add('type_unknown');
  }
  if (input.locationKnown) {
    value += 0.07;
    notes.add('place_known');
  } else {
    value -= 0.10;
    notes.add('place_missing');
  }
  value += 0.03 * input.detailsKnown;
  value -= 0.03 * (input.detailsNeeded - input.detailsKnown);
  return ConfidenceResult(value.clamp(0.05, 0.95), notes);
}

String confidenceNoteText(String key, {required bool english}) {
  const ro = <String, String>{
    'type_clear': 'tip clar din cuvintele tale',
    'type_probable': 'tip probabil',
    'type_weak': 'tip nesigur',
    'type_answered': 'tipul l-ai spus tu',
    'category_only': 'doar categoria e cunoscută',
    'type_unknown': 'tip necunoscut',
    'place_known': 'loc cunoscut',
    'place_missing': 'loc lipsă',
  };
  const en = <String, String>{
    'type_clear': 'type is clear from your words',
    'type_probable': 'probable type',
    'type_weak': 'uncertain type',
    'type_answered': 'you stated the type',
    'category_only': 'only the category is known',
    'type_unknown': 'unknown type',
    'place_known': 'place known',
    'place_missing': 'place missing',
  };
  return (english ? en : ro)[key] ?? key;
}
