// =============================================================================
// lib/core/incidents/likelihood.dart
//
// "Confidence" shown to people is not model certainty — it answers a simpler
// question: how likely is this incident to actually happen at Craiova airport?
//
// The score blends:
//   • incident plausibility (fire/spill/bag are common airport events),
//   • whether the location is a real named zone (from the Craiova catalog),
//   • urgency (critical/high events are reported more reliably).
//
// Used by the reporter confirmation card, the dispatcher cards/detail and the
// desktop control room (same formula mirrored in scripts/dashboard/index.html).
// =============================================================================

import 'taxonomy.dart';

/// Likelihood (0.05–0.98) that this report describes something that can happen
/// at Craiova airport.
double airportLikelihoodOf({
  String? incidentCode,
  String location = '',
  Urgency urgency = Urgency.medium,
}) {
  final type =
      incidentCode == null ? null : IncidentTaxonomy.byCode(incidentCode);

  var score = switch (type?.category) {
    IncidentCategory.safetyFire => 0.90,
    IncidentCategory.security => 0.84,
    IncidentCategory.maintenance => 0.87,
    IncidentCategory.operations => 0.80,
    null => 0.55,
  };

  // A few airport-specific refinements on top of the category base.
  score = switch (incidentCode) {
    'SF-FIRE' => 0.95,
    'SF-SPILL' => 0.93,
    'SF-FOD' => 0.86,
    'SF-EQUIP' => 0.84,
    'SC-BAG' => 0.90,
    'SC-ACCESS' => 0.82,
    'SC-ITEM' => 0.78,
    'SC-BEHAV' => 0.74,
    'MT-BELT' => 0.90,
    'MT-ESC' => 0.82,
    'MT-JBRIDGE' => 0.78,
    'OP-QUEUE' => 0.86,
    'OP-IT' => 0.72,
    'OP-OTHER' => 0.60,
    _ => score,
  };

  final zone = location.trim();
  final hasNamedZone = zone.isNotEmpty &&
      !zone.toLowerCase().contains('nespecificat') &&
      !zone.toLowerCase().contains('unknown');
  score += hasNamedZone ? 0.03 : -0.20;

  if (urgency == Urgency.critical) {
    score += 0.02;
  } else if (urgency == Urgency.high) {
    score += 0.01;
  }

  return score.clamp(0.05, 0.98);
}

String airportLikelihoodPercent(double likelihood) =>
    '${(likelihood * 100).round()}%';
