// Romanian + English keyword stems for the 14 incident types, the four
// categories and the danger signals. Everything is NORMALIZED text (no
// diacritics, lower case).
//
// Stem syntax:
//   'ulei'          prefix of a token  → "ulei", "uleiul", "uleiului"
//   'apa='          the EXACT token    → "apa", but not "apare"
//   'jet bridge'    a phrase (words in order, last word may be a prefix)
//
// This is NOT the classifier of record (the server's Ollama is). It lets the
// app understand what was already said, so it only asks for what is missing,
// and it grades the urgency from what was said instead of from the type alone.

import '../../../core/incidents/taxonomy.dart';

class Stem {
  const Stem(this.stem, [this.weight = 2]);

  final String stem;

  /// 3 = unmistakable, 2 = strong hint, 1 = weak / generic word.
  final int weight;
}

/// Does [stem] occur in the text? [tokens] are the normalized words and
/// [padded] is the normalized text with a space on both ends.
bool stemMatches(String stem, List<String> tokens, String padded) {
  if (stem.endsWith('=')) {
    final exact = stem.substring(0, stem.length - 1);
    return tokens.contains(exact);
  }
  if (stem.contains(' ')) {
    // A phrase: consecutive words, each one a prefix ("iesire de urgenta"
    // also matches "iesirea de urgenta").
    final words = stem.split(' ');
    for (var start = 0; start + words.length <= tokens.length; start++) {
      var all = true;
      for (var k = 0; k < words.length; k++) {
        if (!tokens[start + k].startsWith(words[k])) {
          all = false;
          break;
        }
      }
      if (all) return true;
    }
    return false;
  }
  return tokens.any((token) => token.startsWith(stem));
}

bool anyStemMatches(List<String> stems, List<String> tokens, String padded) =>
    stems.any((stem) => stemMatches(stem, tokens, padded));

const Map<String, List<Stem>> kTypeStems = <String, List<Stem>>{
  // ── Siguranță și incendiu ─────────────────────────────────────────────────
  'SF-FIRE': <Stem>[
    Stem('foc', 3), Stem('fum=', 3), Stem('fumul=', 3), Stem('fumuri=', 3),
    Stem('fumeg', 3), Stem('incendi', 3), Stem('flacar', 3),
    Stem('arde', 3), Stem('arzand', 3), Stem('ia foc', 3),
    Stem('luat foc', 3), Stem('miros de ars', 3), Stem('miros de fum', 3),
    Stem('scantei', 3), Stem('scurtcircuit', 3), Stem('arc electric', 3),
    Stem('supraincalz', 2), Stem('power bank', 2), Stem('powerbank', 2),
    Stem('baterie umflata', 2), Stem('lava=', 3), Stem('magma', 3),
    Stem('vulcan', 3), Stem('volcan', 3), Stem('explozi', 3),
    Stem('explod', 3), Stem('gaz=', 3), Stem('gaze=', 3),
    Stem('miros de gaz', 3), //
    Stem('fire', 3), Stem('smoke', 3), Stem('flame', 3), Stem('burning', 3),
    Stem('on fire', 3), Stem('caught fire', 3), Stem('burnt smell', 3),
    Stem('burning smell', 3), Stem('spark', 3), Stem('short circuit', 3),
    Stem('overheat', 2), Stem('explosion', 3), Stem('explode', 3),
    Stem('gas=', 3), Stem('gas leak', 3), Stem('gas smell', 3),
    Stem('smoking', 2),
  ],
  'SF-FOD': <Stem>[
    Stem('fod=', 3), Stem('corp strain', 3), Stem('foreign object', 3),
    Stem('debris', 3), Stem('surub', 2), Stem('piulita', 2), Stem('piatra', 2),
    Stem('pietris', 2), Stem('resturi', 2), Stem('cauciuc', 2),
    Stem('metal', 2), Stem('sticla=', 2), Stem('plastic=', 2),
    Stem('folie', 2), Stem('ambalaj', 1), Stem('bucata', 1), Stem('obiect', 1),
    Stem('strain', 1), //
    Stem('pasare=', 3), Stem('pasarea=', 3), Stem('pasari=', 3),
    Stem('pasarile=', 3), Stem('animal', 3), Stem('caine', 3),
    Stem('vulpe', 3), Stem('iepure', 3), Stem('cerb=', 3), Stem('wildlife', 3),
    Stem('bird=', 3), Stem('birds=', 3), Stem('dog=', 3), Stem('fox=', 3),
    Stem('rabbit', 3), Stem('deer=', 3), //
    Stem('bolt=', 2), Stem('glass=', 2), Stem('stone=', 1),
    Stem('rubber', 2), Stem('tyre', 2), Stem('tire=', 2),
  ],
  'SF-SPILL': <Stem>[
    Stem('ulei', 3), Stem('scurger', 3), Stem('combustibil', 3),
    Stem('kerosen', 3), Stem('motorin', 3), Stem('benzin', 3),
    Stem('hidraulic', 3), Stem('carburant', 3), Stem('curg', 2),
    Stem('lichid', 2), Stem('alunec', 2), Stem('balta', 2), Stem('varsat', 2),
    Stem('varsatur', 2), Stem('vomit', 2), Stem('apa=', 2), Stem('apei=', 2),
    Stem('teav', 2), Stem('tevi=', 2), Stem('inunda', 3), Stem('picur', 2),
    Stem('infiltrat', 2), Stem('cafea', 2), Stem('bautura', 2), Stem('suc=', 2),
    Stem('gheata=', 2), Stem('poleiu', 2), Stem('zapada', 2), Stem('inghet', 2),
    Stem('podea uda', 2), Stem('pata', 1), Stem('ud=', 1), //
    Stem('oil', 3), Stem('spill', 3), Stem('leak', 3), Stem('fuel', 3),
    Stem('kerosene', 3), Stem('liquid', 2), Stem('puddle', 2),
    Stem('slippery', 2), Stem('wet floor', 2), Stem('water=', 2),
    Stem('flood', 3), Stem('burst pipe', 3), Stem('coffee', 2),
    Stem('drink=', 2),
    Stem('juice=', 2), Stem('ice=', 2), Stem('icy', 2), Stem('snow=', 2),
    Stem('wet=', 1), Stem('stain', 1),
  ],
  'SF-EQUIP': <Stem>[
    Stem('extinctor', 3), Stem('stingator', 3), Stem('hidrant', 3),
    Stem('sprinkler', 3), Stem('sistem de stingere', 3), Stem('detector', 3),
    Stem('iesire de urgenta', 3), Stem('defibrilator', 3), Stem('trusa', 2),
    Stem('prim ajutor', 2), Stem('aed=', 3), //
    Stem('extinguisher', 3), Stem('hydrant', 3), Stem('emergency exit', 3),
    Stem('defibrillator', 3), Stem('first aid', 2), Stem('smoke detector', 3),
  ],
  // ── Securitate ────────────────────────────────────────────────────────────
  'SC-BAG': <Stem>[
    Stem('abandonat', 3), Stem('nesupraveg', 3), Stem('uitat', 2),
    Stem('valiza', 2), Stem('geanta', 2), Stem('rucsac', 2), Stem('pachet', 2),
    Stem('cutie suspecta', 3), Stem('bagaj', 1), //
    Stem('unattended', 3), Stem('abandoned', 3), Stem('suitcase', 2),
    Stem('backpack', 2), Stem('luggage', 1), Stem('suspicious package', 3),
    Stem('suspicious bag', 3), Stem('left behind', 2), Stem('bag=', 1),
  ],
  'SC-ACCESS': <Stem>[
    Stem('neautoriz', 3), Stem('restrictionat', 3), Stem('intrus', 3),
    Stem('fara legitimatie', 3), Stem('fara ecuson', 3),
    Stem('fara acreditare', 3),
    Stem('sarit gardul', 3), Stem('peste gard', 3), Stem('gard=', 2),
    Stem('gardul=', 2),
    Stem('a intrat', 2), Stem('usa fortata', 3), Stem('lacat spart', 3),
    Stem('pasager pe platforma', 3), Stem('pasager pe pista', 3),
    Stem('persoana pe pista', 3), Stem('drona', 3), Stem('drone', 3),
    Stem('acces', 1), //
    Stem('unauthorized', 3), Stem('unauthorised', 3), Stem('restricted', 3),
    Stem('trespass', 3), Stem('intruder', 3), Stem('tailgat', 3),
    Stem('forced door', 3), Stem('broken lock', 3), Stem('fence=', 2),
    Stem('passenger on the apron', 3), Stem('passenger on the runway', 3),
    Stem('person on the runway', 3),
  ],
  'SC-ITEM': <Stem>[
    Stem('cutit', 3), Stem('arma', 3), Stem('pistol', 3), Stem('briceag', 3),
    Stem('explozib', 3), Stem('bomba=', 3), Stem('bombe=', 3),
    Stem('grenad', 3),
    Stem('munitie', 3), Stem('muniti', 3), Stem('droguri', 3),
    Stem('foarfec', 2),
    Stem('spray', 2), Stem('interzis', 2), //
    Stem('knife', 3), Stem('weapon', 3), Stem('gun=', 3), Stem('firearm', 3),
    Stem('bomb=', 3), Stem('explosive', 3), Stem('ammunition', 3),
    Stem('drugs=', 3), Stem('taser', 3), Stem('prohibited', 2),
    Stem('scissors', 2), Stem('banned item', 3),
  ],
  'SC-BEHAV': <Stem>[
    Stem('altercati', 3), Stem('bataie', 3), Stem('se bat', 3),
    Stem('cearta', 3),
    Stem('agresiv', 3), Stem('ameninta', 3), Stem('amenintar', 3),
    Stem('betiv', 3), Stem('ebri', 3), Stem('intoxicat', 3), Stem('scandal', 3),
    Stem('hartuie', 3), Stem('urmareste', 3), Stem('fotografiaza', 2),
    Stem('filmeaza', 2), Stem('agitat', 2), Stem('strig', 2),
    Stem('suspect', 2), Stem('comportament', 2), Stem('fumeaz', 2),
    Stem('fumat', 2), Stem('fumator', 2), //
    Stem('fight', 3), Stem('aggressive', 3), Stem('drunk', 3),
    Stem('threaten', 3),
    Stem('harass', 3), Stem('shouting', 2), Stem('yelling', 2),
    Stem('following', 2), Stem('photograph', 2), Stem('filming', 2),
    Stem('argument', 2), Stem('behaviour', 2), Stem('behavior', 2),
  ],
  // ── Mentenanță ────────────────────────────────────────────────────────────
  'MT-BELT': <Stem>[
    Stem('banda', 3), Stem('transportoar', 3), Stem('carusel', 3),
    Stem('ridicare bagaj', 3), Stem('bagajele nu', 3), //
    Stem('conveyor', 3), Stem('carousel', 3), Stem('belt=', 2),
    Stem('baggage claim', 3), Stem('bags not', 3), Stem('luggage not', 3),
  ],
  'MT-ESC': <Stem>[
    Stem('escalator', 3), Stem('ascensor', 3), Stem('rulant', 3),
    Stem('scara rulanta', 3), Stem('trotuar rulant', 3), Stem('lift', 3),
    Stem('usa automata', 2), Stem('usile automate', 2), Stem('turnichet', 2), //
    Stem('elevator', 3), Stem('travelator', 3), Stem('moving walkway', 3),
    Stem('automatic door', 2), Stem('turnstile', 2),
  ],
  'MT-JBRIDGE': <Stem>[
    Stem('pasarela', 3),
    Stem('burduf', 3),
    Stem('jet bridge', 3),
    Stem('jetbridge', 3),
    Stem('boarding bridge', 3),
    Stem('pbb=', 3),
    Stem('passenger bridge', 3),
  ],
  // ── Operațiuni ────────────────────────────────────────────────────────────
  'OP-QUEUE': <Stem>[
    Stem('aglomer', 3), Stem('coada', 3), Stem('cozi', 3), Stem('inghesu', 3),
    Stem('prea multi oameni', 3), Stem('timp de asteptare', 2),
    Stem('asteptare lunga', 2), //
    Stem('queue', 3), Stem('crowd', 3), Stem('overcrowd', 3),
    Stem('too many people', 3), Stem('long line', 3), Stem('waiting time', 2),
  ],
  'OP-IT': <Stem>[
    Stem('sistemul a cazut', 3), Stem('nu merge sistemul', 3),
    Stem('sistem de bagaje', 3), Stem('calculator', 2), Stem('imprimant', 2),
    Stem('software', 2), Stem('retea', 2), Stem('wifi', 2), Stem('wi fi', 2),
    Stem('internet', 2), Stem('server', 2), Stem('radio=', 2),
    Stem('statie', 1),
    Stem('scanner', 2), Stem('cititor', 2), Stem('afisaj', 2), Stem('ecran', 1),
    Stem('panou de zbor', 3), Stem('check in', 2), Stem('checkin', 2),
    Stem('self service', 2), Stem('kiosk', 2), Stem('sistem', 1), //
    Stem('system down', 3), Stem('system is down', 3), Stem('network', 2),
    Stem('printer', 2), Stem('display', 1), Stem('flight information', 3),
    Stem('fids=', 3), Stem('screen=', 1), Stem('boarding pass', 2),
    Stem('card reader', 2), Stem('communication', 2),
  ],
  // ── Urgențe medicale ──────────
  'OP-MED': <Stem>[
    Stem('lesin', 2), Stem('infarct', 2), Stem('nu respira', 2),
    Stem('convuls', 2), Stem('sufoc', 2), Stem('inec', 2), Stem('ambulanta', 2),
    Stem('medical', 2), Stem('doctor', 2), Stem('sange', 2), Stem('ranit', 2),
    Stem('accident', 2), //
    Stem('faint=', 2), Stem('fainted', 2), Stem('collapsed', 2),
    Stem('heart attack', 2), Stem('not breathing', 2), Stem('seizure', 2),
    Stem('choking', 2), Stem('ambulance', 2), Stem('blood=', 2),
    Stem('injured', 2), Stem('unconscious', 2), Stem('medical emergency', 3),
  ],
};

/// Words that name a CATEGORY (what a reporter says when asked "what kind of
/// problem?": "securitate", "defecțiune", "operațiuni"...).
const Map<IncidentCategory, List<String>> kCategoryWords =
    <IncidentCategory, List<String>>{
  IncidentCategory.safetyFire: <String>['siguranta', 'safety', 'pericol'],
  IncidentCategory.security: <String>[
    'securitate',
    'security',
    'paza',
    'politie',
    'police',
  ],
  IncidentCategory.maintenance: <String>[
    'mentenanta',
    'defectiune',
    'defect',
    'stricat',
    'avarie',
    'tehnic',
    'nu functioneaza',
    'nu merge',
    'maintenance',
    'broken',
    'breakdown',
    'repair',
    'technical',
    'out of order',
    'not working',
  ],
  IncidentCategory.operations: <String>[
    'operatiuni',
    'operational',
    'operatii',
    'operations',
    'organizare',
  ],
};

// ── Danger signals (they raise the URGENCY, never the type) ─────────────────

/// Fire, explosion, gas: always critical.
const List<String> kFireExplosionStems = <String>[
  'lava=',
  'magma',
  'vulcan',
  'volcan',
  'explozi',
  'explod',
  'explos',
  'blast=',
  'bomba=',
  'bomb=',
  'bombe=',
  'grenad',
  'flacar',
  'flame',
  'in flacari',
  'on fire',
  'ia foc',
  'luat foc',
  'caught fire',
  'gaz=',
  'gaze=',
  'gas=',
  'miros de gaz',
  'gas leak',
  'gas smell',
  'incendi',
];

/// Toxic / radioactive / chemical: always critical.
const List<String> kToxicStems = <String>[
  'toxic',
  'chimic',
  'chemical',
  'radiat',
  'acid=',
  'acizi',
  'otrav',
  'poison',
  'monoxid',
  'carbon monoxide',
  'biohazard',
  'hazmat',
  'periculoas',
];

/// A life is at risk: always critical.
const List<String> kLifeStems = <String>[
  'ranit',
  'injur',
  'sange',
  'blood=',
  'inconstient',
  'unconscious',
  'lesin',
  'faint=',
  'collaps',
  'prabus',
  'infarct',
  'heart attack',
  'cardiac',
  'nu respira',
  'not breathing',
  'cant breathe',
  'convuls',
  'seizure',
  'sufoc',
  'choking',
  'inec',
  'drown',
  'ambulanta',
  'ambulance',
  'sinucid',
  'suicid',
  'ostatic',
  'hostage',
  'impusc',
  'shooting',
  'armat',
  'armed=',
  'terorist',
  'terror',
  'stabbed',
  'injunghiat',
  'urgenta medicala',
  'medical emergency',
  'strivit',
  'crushed',
  'electrocut',
  'mort=',
  'moarta=',
  'dead=',
  'death',
];

/// Flammable substance: +1 level.
const List<String> kFlammableStems = <String>[
  'combustibil',
  'kerosen',
  'motorin',
  'benzin',
  'fuel',
  'avgas',
  'jet a1',
  'inflamabil',
  'flammable',
  'carburant',
  'scantei',
  'spark',
  'scurtcircuit',
  'short circuit',
  'supraincalz',
  'overheat',
  'power bank',
  'powerbank',
  'baterie umflata',
  'swollen battery',
  'litiu',
  'lithium',
];

/// It is getting worse: +1 level.
const List<String> kSpreadingStems = <String>[
  'extind',
  'raspand',
  'se intinde',
  'intinde',
  'se mareste',
  'mareste',
  'tot mai',
  'din ce in ce',
  'se agraveaza',
  'agrava',
  'spreading',
  'spread=',
  'growing',
  'getting worse',
  'getting bigger',
  'worsening',
];

/// The reporter says it is urgent: +1 level.
// ("urgent=" and "e urgenta" — NOT "iesire de urgenta" / "emergency exit".)
const List<String> kUrgentStems = <String>[
  'urgent=',
  'urgente=',
  'e urgenta',
  'este o urgenta',
  'repede',
  'imediat',
  'cat mai repede',
  'asap',
  'is an emergency',
  'an emergency',
  'ajutor',
  'help=',
  'sos=',
  'mayday',
  'quickly',
  'immediately',
  'right now',
  'chiar acum',
];

/// Airside / operational areas: +1 level.
const List<String> kAirsideStems = <String>[
  'pista',
  'runway',
  'platforma',
  'apron',
  'airside',
  'taxiway',
  'cale de rulare',
  'calea de rulare',
  'aterizare',
  'decolare',
  'takeoff',
  'take off',
  'hangar',
  'rampa=',
  'ramp=',
  'parcare avioane',
];

/// Next to an aircraft: +1 level.
const List<String> kAircraftStems = <String>[
  'avion',
  'aeronav',
  'aircraft',
  'airplane',
  'plane=',
  'planes=',
  'elicopter',
  'helicopter',
  'aripa',
  'wing=',
  'motor=',
  'motorul=',
  'engine=',
  'engines=',
  'tren de aterizare',
  'landing gear',
  'fuselaj',
  'fuselage',
];

/// Somebody fell or got hurt: +1 level.
const List<String> kFellStems = <String>[
  'a cazut',
  'au cazut',
  'cazut',
  'a alunecat',
  'au alunecat',
  'alunecat',
  'slipped',
  'fell=',
  'fallen',
  'tripped',
  's a lovit',
  'lovit la cap',
  'hit his head',
  'hit her head',
];
