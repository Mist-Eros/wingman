import 'package:flutter/material.dart';

import 'incident_menu_data.dart';
import '../reporter_language.dart';

/// English labels for the deterministic 8×8×8 menu. The codes stay identical;
/// only what the reporter reads changes.
const Map<String, String> _categories = <String, String>{
  'Siguranță și incendiu': 'Safety & fire',
  'Securitate': 'Security',
  'Mentenanță și instalații': 'Maintenance & facilities',
  'Operațiuni aeroport': 'Airport operations',
  'Ground handling și rampă': 'Ground handling & ramp',
  'Aeronave și tehnic': 'Aircraft & technical',
  'Pasageri și terminal': 'Passengers & terminal',
  'Mediu și meteo': 'Environment & weather',
};

const Map<String, String> _subcategories = <String, String>{
  'Incendiu': 'Fire',
  'Fum și miros de ars': 'Smoke & burning smell',
  'Explozie': 'Explosion',
  'Echipamente PSI': 'Fire equipment',
  'Evacuare': 'Evacuation',
  'Persoane în pericol': 'People in danger',
  'Substanțe inflamabile': 'Flammable substances',
  'Alarme și detecție': 'Alarms & detection',
  'Bagaj nesupravegheat': 'Unattended baggage',
  'Bagaj suspect': 'Suspicious baggage',
  'Obiect suspect': 'Suspicious object',
  'Armă sau obiect interzis': 'Weapon or prohibited item',
  'Acces neautorizat': 'Unauthorized access',
  'Persoană turbulentă': 'Disruptive person',
  'Amenințare sau sabotaj': 'Threat or sabotage',
  'Clandestin': 'Stowaway',
  'Bandă de bagaje': 'Baggage belt',
  'Escalator sau lift': 'Escalator or lift',
  'Jet bridge': 'Jet bridge',
  'Uși și acces tehnic': 'Doors & technical access',
  'Iluminat și marcaje': 'Lighting & markings',
  'Instalație electrică': 'Electrical installation',
  'Structură și clădire': 'Structure & building',
  'Echipament aeroportuar': 'Airport equipment',
  'Coadă și aglomerare': 'Queue & congestion',
  'Îmbarcare': 'Boarding',
  'Coordonare cu turnul': 'Tower coordination',
  'Mișcare aeronave': 'Aircraft movement',
  'Stand și parcare': 'Stand & parking',
  'Bagaje și cargo': 'Baggage & cargo',
  'Sisteme IT operaționale': 'Operational IT systems',
  'Servicii pasageri': 'Passenger services',
  'Alimentare cu combustibil': 'Refuelling',
  'Degivrare': 'De-icing',
  'Încărcare și balans': 'Loading & balance',
  'Pushback și remorcare': 'Pushback & towing',
  'Echipamente GSE': 'GSE equipment',
  'Coliziuni pe rampă': 'Ramp collisions',
  'Mărfuri periculoase': 'Dangerous goods',
  'Servire aeronavă': 'Aircraft servicing',
  'Motor și APU': 'Engine & APU',
  'Hidraulic și combustibil': 'Hydraulics & fuel',
  'Cabină și presurizare': 'Cabin & pressurization',
  'Tren de aterizare': 'Landing gear',
  'Structură și avarii': 'Structure & damage',
  'Sisteme electrice': 'Electrical systems',
  'FOD și păsări': 'FOD & wildlife',
  'Urgențe la bord': 'On-board emergencies',
  'Urgență medicală': 'Medical emergency',
  'Accesibilitate': 'Accessibility',
  'Bagaje pasageri': 'Passenger baggage',
  'Copii și persoane dispărute': 'Children & missing persons',
  'Comportament': 'Behaviour',
  'Facilități terminal': 'Terminal facilities',
  'Informare și anunțuri': 'Information & announcements',
  'Vreme severă': 'Severe weather',
  'Zăpadă și gheață': 'Snow & ice',
  'Inundații': 'Flooding',
  'Vânt și jet blast': 'Wind & jet blast',
  'Păsări și animale': 'Birds & animals',
  'Poluare și scurgeri': 'Pollution & spills',
  'Zgomot și lumină': 'Noise & light',
  'Vizibilitate și fum': 'Visibility & smoke',
};

const Map<String, String> _locations = <String, String>{
  'Terminal': 'Terminal',
  'Pistă': 'Runway',
  'Platformă': 'Apron',
  'Hangar': 'Hangar',
  'Parcare': 'Parking',
  'Cargo': 'Cargo',
  'Turn': 'Tower',
  'Poartă': 'Gate',
  'Check-in': 'Check-in',
  'Control securitate': 'Security control',
  'Îmbarcare': 'Boarding',
  'Lounge': 'Lounge',
  'Zona bagaje': 'Baggage area',
  'Stand': 'Stand',
};

String localizedMenuCategory(String ro, ReporterLanguage language) =>
    language == ReporterLanguage.en ? (_categories[ro] ?? ro) : ro;

String localizedMenuSubcategory(String ro, ReporterLanguage language) =>
    language == ReporterLanguage.en ? (_subcategories[ro] ?? ro) : ro;

String localizedMenuProblem(
  MenuSubcategory subcategory,
  MenuProblem problem,
  ReporterLanguage language,
) {
  if (language != ReporterLanguage.en) return problem.label;
  final sub = _subcategories[subcategory.label] ?? subcategory.label;
  final location = _locations[problem.location] ?? problem.location;
  return '$sub — $location';
}

String localizedMenuPath(
  MenuCategory category,
  MenuSubcategory subcategory,
  ReporterLanguage language,
) =>
    '${localizedMenuCategory(category.label, language)} · '
    '${localizedMenuSubcategory(subcategory.label, language)}';

/// Not used for layout; keeps the icon import meaningful for callers.
IconData menuIconFor(MenuCategory category) => category.icon;
