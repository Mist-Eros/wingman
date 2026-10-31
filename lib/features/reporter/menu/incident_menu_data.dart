// GENERATED 8×8×8 menu catalog — 8 categories × 8 subcategories × 8 problems.
// Each problem maps to one of the closed 14 operational codes.
// Regenerate with the generator script; do not hand-edit the 512 entries.

import 'package:flutter/material.dart';

import '../../../core/incidents/taxonomy.dart';

class MenuProblem {
  const MenuProblem(this.id, this.label, this.location, this.typeCode);
  final String id;
  final String label;
  final String location;
  final String typeCode;
}

class MenuSubcategory {
  const MenuSubcategory(this.id, this.label, this.problems);
  final String id;
  final String label;
  final List<MenuProblem> problems;
}

class MenuCategory {
  const MenuCategory(this.id, this.label, this.icon, this.subcategories);
  final String id;
  final String label;
  final IconData icon;
  final List<MenuSubcategory> subcategories;
}

class MenuSelection {
  const MenuSelection(this.category, this.subcategory, this.problem);
  final MenuCategory category;
  final MenuSubcategory subcategory;
  final MenuProblem problem;
  IncidentType get type => IncidentTaxonomy.byCode(problem.typeCode)!;
}

const List<MenuCategory> menuCategories = <MenuCategory>[
  MenuCategory(
    'cat-1',
    'Siguranță și incendiu',
    Icons.local_fire_department_rounded,
    <MenuSubcategory>[
      MenuSubcategory(
        'sub-1-1',
        'Incendiu',
        <MenuProblem>[
          MenuProblem('p-1-1-1', 'Incendiu — Terminal', 'Terminal', 'SF-FIRE'),
          MenuProblem('p-1-1-2', 'Incendiu — Pistă', 'Pistă', 'SF-FIRE'),
          MenuProblem(
              'p-1-1-3', 'Incendiu — Platformă', 'Platformă', 'SF-FIRE'),
          MenuProblem('p-1-1-4', 'Incendiu — Hangar', 'Hangar', 'SF-FIRE'),
          MenuProblem('p-1-1-5', 'Incendiu — Parcare', 'Parcare', 'SF-FIRE'),
          MenuProblem('p-1-1-6', 'Incendiu — Cargo', 'Cargo', 'SF-FIRE'),
          MenuProblem('p-1-1-7', 'Incendiu — Turn', 'Turn', 'SF-FIRE'),
          MenuProblem('p-1-1-8', 'Incendiu — Poartă', 'Poartă', 'SF-FIRE'),
        ],
      ),
      MenuSubcategory(
        'sub-1-2',
        'Fum și miros de ars',
        <MenuProblem>[
          MenuProblem('p-1-2-1', 'Fum și miros de ars — Terminal', 'Terminal',
              'SF-FIRE'),
          MenuProblem(
              'p-1-2-2', 'Fum și miros de ars — Pistă', 'Pistă', 'SF-FIRE'),
          MenuProblem('p-1-2-3', 'Fum și miros de ars — Platformă', 'Platformă',
              'SF-FIRE'),
          MenuProblem(
              'p-1-2-4', 'Fum și miros de ars — Hangar', 'Hangar', 'SF-FIRE'),
          MenuProblem(
              'p-1-2-5', 'Fum și miros de ars — Parcare', 'Parcare', 'SF-FIRE'),
          MenuProblem(
              'p-1-2-6', 'Fum și miros de ars — Cargo', 'Cargo', 'SF-FIRE'),
          MenuProblem(
              'p-1-2-7', 'Fum și miros de ars — Turn', 'Turn', 'SF-FIRE'),
          MenuProblem(
              'p-1-2-8', 'Fum și miros de ars — Poartă', 'Poartă', 'SF-FIRE'),
        ],
      ),
      MenuSubcategory(
        'sub-1-3',
        'Explozie',
        <MenuProblem>[
          MenuProblem('p-1-3-1', 'Explozie — Terminal', 'Terminal', 'SF-FIRE'),
          MenuProblem('p-1-3-2', 'Explozie — Pistă', 'Pistă', 'SF-FIRE'),
          MenuProblem(
              'p-1-3-3', 'Explozie — Platformă', 'Platformă', 'SF-FIRE'),
          MenuProblem('p-1-3-4', 'Explozie — Hangar', 'Hangar', 'SF-FIRE'),
          MenuProblem('p-1-3-5', 'Explozie — Parcare', 'Parcare', 'SF-FIRE'),
          MenuProblem('p-1-3-6', 'Explozie — Cargo', 'Cargo', 'SF-FIRE'),
          MenuProblem('p-1-3-7', 'Explozie — Turn', 'Turn', 'SF-FIRE'),
          MenuProblem('p-1-3-8', 'Explozie — Poartă', 'Poartă', 'SF-FIRE'),
        ],
      ),
      MenuSubcategory(
        'sub-1-4',
        'Echipamente PSI',
        <MenuProblem>[
          MenuProblem(
              'p-1-4-1', 'Echipamente PSI — Terminal', 'Terminal', 'SF-EQUIP'),
          MenuProblem(
              'p-1-4-2', 'Echipamente PSI — Pistă', 'Pistă', 'SF-EQUIP'),
          MenuProblem('p-1-4-3', 'Echipamente PSI — Platformă', 'Platformă',
              'SF-EQUIP'),
          MenuProblem(
              'p-1-4-4', 'Echipamente PSI — Hangar', 'Hangar', 'SF-EQUIP'),
          MenuProblem(
              'p-1-4-5', 'Echipamente PSI — Parcare', 'Parcare', 'SF-EQUIP'),
          MenuProblem(
              'p-1-4-6', 'Echipamente PSI — Cargo', 'Cargo', 'SF-EQUIP'),
          MenuProblem('p-1-4-7', 'Echipamente PSI — Turn', 'Turn', 'SF-EQUIP'),
          MenuProblem(
              'p-1-4-8', 'Echipamente PSI — Poartă', 'Poartă', 'SF-EQUIP'),
        ],
      ),
      MenuSubcategory(
        'sub-1-5',
        'Evacuare',
        <MenuProblem>[
          MenuProblem('p-1-5-1', 'Evacuare — Terminal', 'Terminal', 'OP-OTHER'),
          MenuProblem('p-1-5-2', 'Evacuare — Pistă', 'Pistă', 'OP-OTHER'),
          MenuProblem(
              'p-1-5-3', 'Evacuare — Platformă', 'Platformă', 'OP-OTHER'),
          MenuProblem('p-1-5-4', 'Evacuare — Hangar', 'Hangar', 'OP-OTHER'),
          MenuProblem('p-1-5-5', 'Evacuare — Parcare', 'Parcare', 'OP-OTHER'),
          MenuProblem('p-1-5-6', 'Evacuare — Cargo', 'Cargo', 'OP-OTHER'),
          MenuProblem('p-1-5-7', 'Evacuare — Turn', 'Turn', 'OP-OTHER'),
          MenuProblem('p-1-5-8', 'Evacuare — Poartă', 'Poartă', 'OP-OTHER'),
        ],
      ),
      MenuSubcategory(
        'sub-1-6',
        'Persoane în pericol',
        <MenuProblem>[
          MenuProblem('p-1-6-1', 'Persoane în pericol — Terminal', 'Terminal',
              'OP-OTHER'),
          MenuProblem(
              'p-1-6-2', 'Persoane în pericol — Pistă', 'Pistă', 'OP-OTHER'),
          MenuProblem('p-1-6-3', 'Persoane în pericol — Platformă', 'Platformă',
              'OP-OTHER'),
          MenuProblem(
              'p-1-6-4', 'Persoane în pericol — Hangar', 'Hangar', 'OP-OTHER'),
          MenuProblem('p-1-6-5', 'Persoane în pericol — Parcare', 'Parcare',
              'OP-OTHER'),
          MenuProblem(
              'p-1-6-6', 'Persoane în pericol — Cargo', 'Cargo', 'OP-OTHER'),
          MenuProblem(
              'p-1-6-7', 'Persoane în pericol — Turn', 'Turn', 'OP-OTHER'),
          MenuProblem(
              'p-1-6-8', 'Persoane în pericol — Poartă', 'Poartă', 'OP-OTHER'),
        ],
      ),
      MenuSubcategory(
        'sub-1-7',
        'Substanțe inflamabile',
        <MenuProblem>[
          MenuProblem('p-1-7-1', 'Substanțe inflamabile — Terminal', 'Terminal',
              'SF-FIRE'),
          MenuProblem(
              'p-1-7-2', 'Substanțe inflamabile — Pistă', 'Pistă', 'SF-FIRE'),
          MenuProblem('p-1-7-3', 'Substanțe inflamabile — Platformă',
              'Platformă', 'SF-FIRE'),
          MenuProblem(
              'p-1-7-4', 'Substanțe inflamabile — Hangar', 'Hangar', 'SF-FIRE'),
          MenuProblem('p-1-7-5', 'Substanțe inflamabile — Parcare', 'Parcare',
              'SF-FIRE'),
          MenuProblem(
              'p-1-7-6', 'Substanțe inflamabile — Cargo', 'Cargo', 'SF-FIRE'),
          MenuProblem(
              'p-1-7-7', 'Substanțe inflamabile — Turn', 'Turn', 'SF-FIRE'),
          MenuProblem(
              'p-1-7-8', 'Substanțe inflamabile — Poartă', 'Poartă', 'SF-FIRE'),
        ],
      ),
      MenuSubcategory(
        'sub-1-8',
        'Alarme și detecție',
        <MenuProblem>[
          MenuProblem('p-1-8-1', 'Alarme și detecție — Terminal', 'Terminal',
              'SF-EQUIP'),
          MenuProblem(
              'p-1-8-2', 'Alarme și detecție — Pistă', 'Pistă', 'SF-EQUIP'),
          MenuProblem('p-1-8-3', 'Alarme și detecție — Platformă', 'Platformă',
              'SF-EQUIP'),
          MenuProblem(
              'p-1-8-4', 'Alarme și detecție — Hangar', 'Hangar', 'SF-EQUIP'),
          MenuProblem(
              'p-1-8-5', 'Alarme și detecție — Parcare', 'Parcare', 'SF-EQUIP'),
          MenuProblem(
              'p-1-8-6', 'Alarme și detecție — Cargo', 'Cargo', 'SF-EQUIP'),
          MenuProblem(
              'p-1-8-7', 'Alarme și detecție — Turn', 'Turn', 'SF-EQUIP'),
          MenuProblem(
              'p-1-8-8', 'Alarme și detecție — Poartă', 'Poartă', 'SF-EQUIP'),
        ],
      ),
    ],
  ),
  MenuCategory(
    'cat-2',
    'Securitate',
    Icons.shield_outlined,
    <MenuSubcategory>[
      MenuSubcategory(
        'sub-2-1',
        'Bagaj nesupravegheat',
        <MenuProblem>[
          MenuProblem('p-2-1-1', 'Bagaj nesupravegheat — Terminal', 'Terminal',
              'SC-BAG'),
          MenuProblem('p-2-1-2', 'Bagaj nesupravegheat — Control securitate',
              'Control securitate', 'SC-BAG'),
          MenuProblem(
              'p-2-1-3', 'Bagaj nesupravegheat — Poartă', 'Poartă', 'SC-BAG'),
          MenuProblem('p-2-1-4', 'Bagaj nesupravegheat — Platformă',
              'Platformă', 'SC-BAG'),
          MenuProblem('p-2-1-5', 'Bagaj nesupravegheat — Zona bagaje',
              'Zona bagaje', 'SC-BAG'),
          MenuProblem(
              'p-2-1-6', 'Bagaj nesupravegheat — Parcare', 'Parcare', 'SC-BAG'),
          MenuProblem(
              'p-2-1-7', 'Bagaj nesupravegheat — Cargo', 'Cargo', 'SC-BAG'),
          MenuProblem('p-2-1-8', 'Bagaj nesupravegheat — Zonă restricționată',
              'Zonă restricționată', 'SC-BAG'),
        ],
      ),
      MenuSubcategory(
        'sub-2-2',
        'Bagaj suspect',
        <MenuProblem>[
          MenuProblem(
              'p-2-2-1', 'Bagaj suspect — Terminal', 'Terminal', 'SC-BAG'),
          MenuProblem('p-2-2-2', 'Bagaj suspect — Control securitate',
              'Control securitate', 'SC-BAG'),
          MenuProblem('p-2-2-3', 'Bagaj suspect — Poartă', 'Poartă', 'SC-BAG'),
          MenuProblem(
              'p-2-2-4', 'Bagaj suspect — Platformă', 'Platformă', 'SC-BAG'),
          MenuProblem('p-2-2-5', 'Bagaj suspect — Zona bagaje', 'Zona bagaje',
              'SC-BAG'),
          MenuProblem(
              'p-2-2-6', 'Bagaj suspect — Parcare', 'Parcare', 'SC-BAG'),
          MenuProblem('p-2-2-7', 'Bagaj suspect — Cargo', 'Cargo', 'SC-BAG'),
          MenuProblem('p-2-2-8', 'Bagaj suspect — Zonă restricționată',
              'Zonă restricționată', 'SC-BAG'),
        ],
      ),
      MenuSubcategory(
        'sub-2-3',
        'Obiect suspect',
        <MenuProblem>[
          MenuProblem(
              'p-2-3-1', 'Obiect suspect — Terminal', 'Terminal', 'SC-ITEM'),
          MenuProblem('p-2-3-2', 'Obiect suspect — Control securitate',
              'Control securitate', 'SC-ITEM'),
          MenuProblem(
              'p-2-3-3', 'Obiect suspect — Poartă', 'Poartă', 'SC-ITEM'),
          MenuProblem(
              'p-2-3-4', 'Obiect suspect — Platformă', 'Platformă', 'SC-ITEM'),
          MenuProblem('p-2-3-5', 'Obiect suspect — Zona bagaje', 'Zona bagaje',
              'SC-ITEM'),
          MenuProblem(
              'p-2-3-6', 'Obiect suspect — Parcare', 'Parcare', 'SC-ITEM'),
          MenuProblem('p-2-3-7', 'Obiect suspect — Cargo', 'Cargo', 'SC-ITEM'),
          MenuProblem('p-2-3-8', 'Obiect suspect — Zonă restricționată',
              'Zonă restricționată', 'SC-ITEM'),
        ],
      ),
      MenuSubcategory(
        'sub-2-4',
        'Armă sau obiect interzis',
        <MenuProblem>[
          MenuProblem('p-2-4-1', 'Armă sau obiect interzis — Terminal',
              'Terminal', 'SC-ITEM'),
          MenuProblem(
              'p-2-4-2',
              'Armă sau obiect interzis — Control securitate',
              'Control securitate',
              'SC-ITEM'),
          MenuProblem('p-2-4-3', 'Armă sau obiect interzis — Poartă', 'Poartă',
              'SC-ITEM'),
          MenuProblem('p-2-4-4', 'Armă sau obiect interzis — Platformă',
              'Platformă', 'SC-ITEM'),
          MenuProblem('p-2-4-5', 'Armă sau obiect interzis — Zona bagaje',
              'Zona bagaje', 'SC-ITEM'),
          MenuProblem('p-2-4-6', 'Armă sau obiect interzis — Parcare',
              'Parcare', 'SC-ITEM'),
          MenuProblem('p-2-4-7', 'Armă sau obiect interzis — Cargo', 'Cargo',
              'SC-ITEM'),
          MenuProblem(
              'p-2-4-8',
              'Armă sau obiect interzis — Zonă restricționată',
              'Zonă restricționată',
              'SC-ITEM'),
        ],
      ),
      MenuSubcategory(
        'sub-2-5',
        'Acces neautorizat',
        <MenuProblem>[
          MenuProblem('p-2-5-1', 'Acces neautorizat — Terminal', 'Terminal',
              'SC-ACCESS'),
          MenuProblem('p-2-5-2', 'Acces neautorizat — Control securitate',
              'Control securitate', 'SC-ACCESS'),
          MenuProblem(
              'p-2-5-3', 'Acces neautorizat — Poartă', 'Poartă', 'SC-ACCESS'),
          MenuProblem('p-2-5-4', 'Acces neautorizat — Platformă', 'Platformă',
              'SC-ACCESS'),
          MenuProblem('p-2-5-5', 'Acces neautorizat — Zona bagaje',
              'Zona bagaje', 'SC-ACCESS'),
          MenuProblem(
              'p-2-5-6', 'Acces neautorizat — Parcare', 'Parcare', 'SC-ACCESS'),
          MenuProblem(
              'p-2-5-7', 'Acces neautorizat — Cargo', 'Cargo', 'SC-ACCESS'),
          MenuProblem('p-2-5-8', 'Acces neautorizat — Zonă restricționată',
              'Zonă restricționată', 'SC-ACCESS'),
        ],
      ),
      MenuSubcategory(
        'sub-2-6',
        'Persoană turbulentă',
        <MenuProblem>[
          MenuProblem('p-2-6-1', 'Persoană turbulentă — Terminal', 'Terminal',
              'SC-BEHAV'),
          MenuProblem('p-2-6-2', 'Persoană turbulentă — Control securitate',
              'Control securitate', 'SC-BEHAV'),
          MenuProblem(
              'p-2-6-3', 'Persoană turbulentă — Poartă', 'Poartă', 'SC-BEHAV'),
          MenuProblem('p-2-6-4', 'Persoană turbulentă — Platformă', 'Platformă',
              'SC-BEHAV'),
          MenuProblem('p-2-6-5', 'Persoană turbulentă — Zona bagaje',
              'Zona bagaje', 'SC-BEHAV'),
          MenuProblem('p-2-6-6', 'Persoană turbulentă — Parcare', 'Parcare',
              'SC-BEHAV'),
          MenuProblem(
              'p-2-6-7', 'Persoană turbulentă — Cargo', 'Cargo', 'SC-BEHAV'),
          MenuProblem('p-2-6-8', 'Persoană turbulentă — Zonă restricționată',
              'Zonă restricționată', 'SC-BEHAV'),
        ],
      ),
      MenuSubcategory(
        'sub-2-7',
        'Amenințare sau sabotaj',
        <MenuProblem>[
          MenuProblem('p-2-7-1', 'Amenințare sau sabotaj — Terminal',
              'Terminal', 'SC-BEHAV'),
          MenuProblem('p-2-7-2', 'Amenințare sau sabotaj — Control securitate',
              'Control securitate', 'SC-BEHAV'),
          MenuProblem('p-2-7-3', 'Amenințare sau sabotaj — Poartă', 'Poartă',
              'SC-BEHAV'),
          MenuProblem('p-2-7-4', 'Amenințare sau sabotaj — Platformă',
              'Platformă', 'SC-BEHAV'),
          MenuProblem('p-2-7-5', 'Amenințare sau sabotaj — Zona bagaje',
              'Zona bagaje', 'SC-BEHAV'),
          MenuProblem('p-2-7-6', 'Amenințare sau sabotaj — Parcare', 'Parcare',
              'SC-BEHAV'),
          MenuProblem(
              'p-2-7-7', 'Amenințare sau sabotaj — Cargo', 'Cargo', 'SC-BEHAV'),
          MenuProblem('p-2-7-8', 'Amenințare sau sabotaj — Zonă restricționată',
              'Zonă restricționată', 'SC-BEHAV'),
        ],
      ),
      MenuSubcategory(
        'sub-2-8',
        'Clandestin',
        <MenuProblem>[
          MenuProblem(
              'p-2-8-1', 'Clandestin — Terminal', 'Terminal', 'SC-ACCESS'),
          MenuProblem('p-2-8-2', 'Clandestin — Control securitate',
              'Control securitate', 'SC-ACCESS'),
          MenuProblem('p-2-8-3', 'Clandestin — Poartă', 'Poartă', 'SC-ACCESS'),
          MenuProblem(
              'p-2-8-4', 'Clandestin — Platformă', 'Platformă', 'SC-ACCESS'),
          MenuProblem('p-2-8-5', 'Clandestin — Zona bagaje', 'Zona bagaje',
              'SC-ACCESS'),
          MenuProblem(
              'p-2-8-6', 'Clandestin — Parcare', 'Parcare', 'SC-ACCESS'),
          MenuProblem('p-2-8-7', 'Clandestin — Cargo', 'Cargo', 'SC-ACCESS'),
          MenuProblem('p-2-8-8', 'Clandestin — Zonă restricționată',
              'Zonă restricționată', 'SC-ACCESS'),
        ],
      ),
    ],
  ),
  MenuCategory(
    'cat-3',
    'Mentenanță și instalații',
    Icons.build_outlined,
    <MenuSubcategory>[
      MenuSubcategory(
        'sub-3-1',
        'Bandă de bagaje',
        <MenuProblem>[
          MenuProblem(
              'p-3-1-1', 'Bandă de bagaje — Terminal', 'Terminal', 'MT-BELT'),
          MenuProblem('p-3-1-2', 'Bandă de bagaje — Bandă bagaje',
              'Bandă bagaje', 'MT-BELT'),
          MenuProblem(
              'p-3-1-3', 'Bandă de bagaje — Escalator', 'Escalator', 'MT-BELT'),
          MenuProblem('p-3-1-4', 'Bandă de bagaje — Jet bridge', 'Jet bridge',
              'MT-BELT'),
          MenuProblem(
              'p-3-1-5', 'Bandă de bagaje — Platformă', 'Platformă', 'MT-BELT'),
          MenuProblem(
              'p-3-1-6', 'Bandă de bagaje — Parcare', 'Parcare', 'MT-BELT'),
          MenuProblem(
              'p-3-1-7', 'Bandă de bagaje — Hangar', 'Hangar', 'MT-BELT'),
          MenuProblem('p-3-1-8', 'Bandă de bagaje — Cargo', 'Cargo', 'MT-BELT'),
        ],
      ),
      MenuSubcategory(
        'sub-3-2',
        'Escalator sau lift',
        <MenuProblem>[
          MenuProblem(
              'p-3-2-1', 'Escalator sau lift — Terminal', 'Terminal', 'MT-ESC'),
          MenuProblem('p-3-2-2', 'Escalator sau lift — Bandă bagaje',
              'Bandă bagaje', 'MT-ESC'),
          MenuProblem('p-3-2-3', 'Escalator sau lift — Escalator', 'Escalator',
              'MT-ESC'),
          MenuProblem('p-3-2-4', 'Escalator sau lift — Jet bridge',
              'Jet bridge', 'MT-ESC'),
          MenuProblem('p-3-2-5', 'Escalator sau lift — Platformă', 'Platformă',
              'MT-ESC'),
          MenuProblem(
              'p-3-2-6', 'Escalator sau lift — Parcare', 'Parcare', 'MT-ESC'),
          MenuProblem(
              'p-3-2-7', 'Escalator sau lift — Hangar', 'Hangar', 'MT-ESC'),
          MenuProblem(
              'p-3-2-8', 'Escalator sau lift — Cargo', 'Cargo', 'MT-ESC'),
        ],
      ),
      MenuSubcategory(
        'sub-3-3',
        'Jet bridge',
        <MenuProblem>[
          MenuProblem(
              'p-3-3-1', 'Jet bridge — Terminal', 'Terminal', 'MT-JBRIDGE'),
          MenuProblem('p-3-3-2', 'Jet bridge — Bandă bagaje', 'Bandă bagaje',
              'MT-JBRIDGE'),
          MenuProblem(
              'p-3-3-3', 'Jet bridge — Escalator', 'Escalator', 'MT-JBRIDGE'),
          MenuProblem(
              'p-3-3-4', 'Jet bridge — Jet bridge', 'Jet bridge', 'MT-JBRIDGE'),
          MenuProblem(
              'p-3-3-5', 'Jet bridge — Platformă', 'Platformă', 'MT-JBRIDGE'),
          MenuProblem(
              'p-3-3-6', 'Jet bridge — Parcare', 'Parcare', 'MT-JBRIDGE'),
          MenuProblem('p-3-3-7', 'Jet bridge — Hangar', 'Hangar', 'MT-JBRIDGE'),
          MenuProblem('p-3-3-8', 'Jet bridge — Cargo', 'Cargo', 'MT-JBRIDGE'),
        ],
      ),
      MenuSubcategory(
        'sub-3-4',
        'Uși și acces tehnic',
        <MenuProblem>[
          MenuProblem('p-3-4-1', 'Uși și acces tehnic — Terminal', 'Terminal',
              'MT-ESC'),
          MenuProblem('p-3-4-2', 'Uși și acces tehnic — Bandă bagaje',
              'Bandă bagaje', 'MT-ESC'),
          MenuProblem('p-3-4-3', 'Uși și acces tehnic — Escalator', 'Escalator',
              'MT-ESC'),
          MenuProblem('p-3-4-4', 'Uși și acces tehnic — Jet bridge',
              'Jet bridge', 'MT-ESC'),
          MenuProblem('p-3-4-5', 'Uși și acces tehnic — Platformă', 'Platformă',
              'MT-ESC'),
          MenuProblem(
              'p-3-4-6', 'Uși și acces tehnic — Parcare', 'Parcare', 'MT-ESC'),
          MenuProblem(
              'p-3-4-7', 'Uși și acces tehnic — Hangar', 'Hangar', 'MT-ESC'),
          MenuProblem(
              'p-3-4-8', 'Uși și acces tehnic — Cargo', 'Cargo', 'MT-ESC'),
        ],
      ),
      MenuSubcategory(
        'sub-3-5',
        'Iluminat și marcaje',
        <MenuProblem>[
          MenuProblem('p-3-5-1', 'Iluminat și marcaje — Terminal', 'Terminal',
              'SF-EQUIP'),
          MenuProblem('p-3-5-2', 'Iluminat și marcaje — Bandă bagaje',
              'Bandă bagaje', 'SF-EQUIP'),
          MenuProblem('p-3-5-3', 'Iluminat și marcaje — Escalator', 'Escalator',
              'SF-EQUIP'),
          MenuProblem('p-3-5-4', 'Iluminat și marcaje — Jet bridge',
              'Jet bridge', 'SF-EQUIP'),
          MenuProblem('p-3-5-5', 'Iluminat și marcaje — Platformă', 'Platformă',
              'SF-EQUIP'),
          MenuProblem('p-3-5-6', 'Iluminat și marcaje — Parcare', 'Parcare',
              'SF-EQUIP'),
          MenuProblem(
              'p-3-5-7', 'Iluminat și marcaje — Hangar', 'Hangar', 'SF-EQUIP'),
          MenuProblem(
              'p-3-5-8', 'Iluminat și marcaje — Cargo', 'Cargo', 'SF-EQUIP'),
        ],
      ),
      MenuSubcategory(
        'sub-3-6',
        'Instalație electrică',
        <MenuProblem>[
          MenuProblem('p-3-6-1', 'Instalație electrică — Terminal', 'Terminal',
              'SF-EQUIP'),
          MenuProblem('p-3-6-2', 'Instalație electrică — Bandă bagaje',
              'Bandă bagaje', 'SF-EQUIP'),
          MenuProblem('p-3-6-3', 'Instalație electrică — Escalator',
              'Escalator', 'SF-EQUIP'),
          MenuProblem('p-3-6-4', 'Instalație electrică — Jet bridge',
              'Jet bridge', 'SF-EQUIP'),
          MenuProblem('p-3-6-5', 'Instalație electrică — Platformă',
              'Platformă', 'SF-EQUIP'),
          MenuProblem('p-3-6-6', 'Instalație electrică — Parcare', 'Parcare',
              'SF-EQUIP'),
          MenuProblem(
              'p-3-6-7', 'Instalație electrică — Hangar', 'Hangar', 'SF-EQUIP'),
          MenuProblem(
              'p-3-6-8', 'Instalație electrică — Cargo', 'Cargo', 'SF-EQUIP'),
        ],
      ),
      MenuSubcategory(
        'sub-3-7',
        'Structură și clădire',
        <MenuProblem>[
          MenuProblem('p-3-7-1', 'Structură și clădire — Terminal', 'Terminal',
              'SF-EQUIP'),
          MenuProblem('p-3-7-2', 'Structură și clădire — Bandă bagaje',
              'Bandă bagaje', 'SF-EQUIP'),
          MenuProblem('p-3-7-3', 'Structură și clădire — Escalator',
              'Escalator', 'SF-EQUIP'),
          MenuProblem('p-3-7-4', 'Structură și clădire — Jet bridge',
              'Jet bridge', 'SF-EQUIP'),
          MenuProblem('p-3-7-5', 'Structură și clădire — Platformă',
              'Platformă', 'SF-EQUIP'),
          MenuProblem('p-3-7-6', 'Structură și clădire — Parcare', 'Parcare',
              'SF-EQUIP'),
          MenuProblem(
              'p-3-7-7', 'Structură și clădire — Hangar', 'Hangar', 'SF-EQUIP'),
          MenuProblem(
              'p-3-7-8', 'Structură și clădire — Cargo', 'Cargo', 'SF-EQUIP'),
        ],
      ),
      MenuSubcategory(
        'sub-3-8',
        'Echipament aeroportuar',
        <MenuProblem>[
          MenuProblem('p-3-8-1', 'Echipament aeroportuar — Terminal',
              'Terminal', 'SF-EQUIP'),
          MenuProblem('p-3-8-2', 'Echipament aeroportuar — Bandă bagaje',
              'Bandă bagaje', 'SF-EQUIP'),
          MenuProblem('p-3-8-3', 'Echipament aeroportuar — Escalator',
              'Escalator', 'SF-EQUIP'),
          MenuProblem('p-3-8-4', 'Echipament aeroportuar — Jet bridge',
              'Jet bridge', 'SF-EQUIP'),
          MenuProblem('p-3-8-5', 'Echipament aeroportuar — Platformă',
              'Platformă', 'SF-EQUIP'),
          MenuProblem('p-3-8-6', 'Echipament aeroportuar — Parcare', 'Parcare',
              'SF-EQUIP'),
          MenuProblem('p-3-8-7', 'Echipament aeroportuar — Hangar', 'Hangar',
              'SF-EQUIP'),
          MenuProblem(
              'p-3-8-8', 'Echipament aeroportuar — Cargo', 'Cargo', 'SF-EQUIP'),
        ],
      ),
    ],
  ),
  MenuCategory(
    'cat-4',
    'Operațiuni aeroport',
    Icons.flight_takeoff,
    <MenuSubcategory>[
      MenuSubcategory(
        'sub-4-1',
        'Coadă și aglomerare',
        <MenuProblem>[
          MenuProblem('p-4-1-1', 'Coadă și aglomerare — Check-in', 'Check-in',
              'OP-QUEUE'),
          MenuProblem('p-4-1-2', 'Coadă și aglomerare — Control securitate',
              'Control securitate', 'OP-QUEUE'),
          MenuProblem('p-4-1-3', 'Coadă și aglomerare — Îmbarcare', 'Îmbarcare',
              'OP-QUEUE'),
          MenuProblem('p-4-1-4', 'Coadă și aglomerare — Platformă', 'Platformă',
              'OP-QUEUE'),
          MenuProblem(
              'p-4-1-5', 'Coadă și aglomerare — Pistă', 'Pistă', 'OP-QUEUE'),
          MenuProblem('p-4-1-6', 'Coadă și aglomerare — Parcare', 'Parcare',
              'OP-QUEUE'),
          MenuProblem(
              'p-4-1-7', 'Coadă și aglomerare — Poartă', 'Poartă', 'OP-QUEUE'),
          MenuProblem('p-4-1-8', 'Coadă și aglomerare — Terminal', 'Terminal',
              'OP-QUEUE'),
        ],
      ),
      MenuSubcategory(
        'sub-4-2',
        'Îmbarcare',
        <MenuProblem>[
          MenuProblem(
              'p-4-2-1', 'Îmbarcare — Check-in', 'Check-in', 'OP-QUEUE'),
          MenuProblem('p-4-2-2', 'Îmbarcare — Control securitate',
              'Control securitate', 'OP-QUEUE'),
          MenuProblem(
              'p-4-2-3', 'Îmbarcare — Îmbarcare', 'Îmbarcare', 'OP-QUEUE'),
          MenuProblem(
              'p-4-2-4', 'Îmbarcare — Platformă', 'Platformă', 'OP-QUEUE'),
          MenuProblem('p-4-2-5', 'Îmbarcare — Pistă', 'Pistă', 'OP-QUEUE'),
          MenuProblem('p-4-2-6', 'Îmbarcare — Parcare', 'Parcare', 'OP-QUEUE'),
          MenuProblem('p-4-2-7', 'Îmbarcare — Poartă', 'Poartă', 'OP-QUEUE'),
          MenuProblem(
              'p-4-2-8', 'Îmbarcare — Terminal', 'Terminal', 'OP-QUEUE'),
        ],
      ),
      MenuSubcategory(
        'sub-4-3',
        'Coordonare cu turnul',
        <MenuProblem>[
          MenuProblem('p-4-3-1', 'Coordonare cu turnul — Check-in', 'Check-in',
              'OP-OTHER'),
          MenuProblem('p-4-3-2', 'Coordonare cu turnul — Control securitate',
              'Control securitate', 'OP-OTHER'),
          MenuProblem('p-4-3-3', 'Coordonare cu turnul — Îmbarcare',
              'Îmbarcare', 'OP-OTHER'),
          MenuProblem('p-4-3-4', 'Coordonare cu turnul — Platformă',
              'Platformă', 'OP-OTHER'),
          MenuProblem(
              'p-4-3-5', 'Coordonare cu turnul — Pistă', 'Pistă', 'OP-OTHER'),
          MenuProblem('p-4-3-6', 'Coordonare cu turnul — Parcare', 'Parcare',
              'OP-OTHER'),
          MenuProblem(
              'p-4-3-7', 'Coordonare cu turnul — Poartă', 'Poartă', 'OP-OTHER'),
          MenuProblem('p-4-3-8', 'Coordonare cu turnul — Terminal', 'Terminal',
              'OP-OTHER'),
        ],
      ),
      MenuSubcategory(
        'sub-4-4',
        'Mișcare aeronave',
        <MenuProblem>[
          MenuProblem(
              'p-4-4-1', 'Mișcare aeronave — Check-in', 'Check-in', 'OP-OTHER'),
          MenuProblem('p-4-4-2', 'Mișcare aeronave — Control securitate',
              'Control securitate', 'OP-OTHER'),
          MenuProblem('p-4-4-3', 'Mișcare aeronave — Îmbarcare', 'Îmbarcare',
              'OP-OTHER'),
          MenuProblem('p-4-4-4', 'Mișcare aeronave — Platformă', 'Platformă',
              'OP-OTHER'),
          MenuProblem(
              'p-4-4-5', 'Mișcare aeronave — Pistă', 'Pistă', 'OP-OTHER'),
          MenuProblem(
              'p-4-4-6', 'Mișcare aeronave — Parcare', 'Parcare', 'OP-OTHER'),
          MenuProblem(
              'p-4-4-7', 'Mișcare aeronave — Poartă', 'Poartă', 'OP-OTHER'),
          MenuProblem(
              'p-4-4-8', 'Mișcare aeronave — Terminal', 'Terminal', 'OP-OTHER'),
        ],
      ),
      MenuSubcategory(
        'sub-4-5',
        'Stand și parcare',
        <MenuProblem>[
          MenuProblem(
              'p-4-5-1', 'Stand și parcare — Check-in', 'Check-in', 'OP-OTHER'),
          MenuProblem('p-4-5-2', 'Stand și parcare — Control securitate',
              'Control securitate', 'OP-OTHER'),
          MenuProblem('p-4-5-3', 'Stand și parcare — Îmbarcare', 'Îmbarcare',
              'OP-OTHER'),
          MenuProblem('p-4-5-4', 'Stand și parcare — Platformă', 'Platformă',
              'OP-OTHER'),
          MenuProblem(
              'p-4-5-5', 'Stand și parcare — Pistă', 'Pistă', 'OP-OTHER'),
          MenuProblem(
              'p-4-5-6', 'Stand și parcare — Parcare', 'Parcare', 'OP-OTHER'),
          MenuProblem(
              'p-4-5-7', 'Stand și parcare — Poartă', 'Poartă', 'OP-OTHER'),
          MenuProblem(
              'p-4-5-8', 'Stand și parcare — Terminal', 'Terminal', 'OP-OTHER'),
        ],
      ),
      MenuSubcategory(
        'sub-4-6',
        'Bagaje și cargo',
        <MenuProblem>[
          MenuProblem(
              'p-4-6-1', 'Bagaje și cargo — Check-in', 'Check-in', 'OP-OTHER'),
          MenuProblem('p-4-6-2', 'Bagaje și cargo — Control securitate',
              'Control securitate', 'OP-OTHER'),
          MenuProblem('p-4-6-3', 'Bagaje și cargo — Îmbarcare', 'Îmbarcare',
              'OP-OTHER'),
          MenuProblem('p-4-6-4', 'Bagaje și cargo — Platformă', 'Platformă',
              'OP-OTHER'),
          MenuProblem(
              'p-4-6-5', 'Bagaje și cargo — Pistă', 'Pistă', 'OP-OTHER'),
          MenuProblem(
              'p-4-6-6', 'Bagaje și cargo — Parcare', 'Parcare', 'OP-OTHER'),
          MenuProblem(
              'p-4-6-7', 'Bagaje și cargo — Poartă', 'Poartă', 'OP-OTHER'),
          MenuProblem(
              'p-4-6-8', 'Bagaje și cargo — Terminal', 'Terminal', 'OP-OTHER'),
        ],
      ),
      MenuSubcategory(
        'sub-4-7',
        'Sisteme IT operaționale',
        <MenuProblem>[
          MenuProblem('p-4-7-1', 'Sisteme IT operaționale — Check-in',
              'Check-in', 'OP-IT'),
          MenuProblem('p-4-7-2', 'Sisteme IT operaționale — Control securitate',
              'Control securitate', 'OP-IT'),
          MenuProblem('p-4-7-3', 'Sisteme IT operaționale — Îmbarcare',
              'Îmbarcare', 'OP-IT'),
          MenuProblem('p-4-7-4', 'Sisteme IT operaționale — Platformă',
              'Platformă', 'OP-IT'),
          MenuProblem(
              'p-4-7-5', 'Sisteme IT operaționale — Pistă', 'Pistă', 'OP-IT'),
          MenuProblem('p-4-7-6', 'Sisteme IT operaționale — Parcare', 'Parcare',
              'OP-IT'),
          MenuProblem(
              'p-4-7-7', 'Sisteme IT operaționale — Poartă', 'Poartă', 'OP-IT'),
          MenuProblem('p-4-7-8', 'Sisteme IT operaționale — Terminal',
              'Terminal', 'OP-IT'),
        ],
      ),
      MenuSubcategory(
        'sub-4-8',
        'Servicii pasageri',
        <MenuProblem>[
          MenuProblem('p-4-8-1', 'Servicii pasageri — Check-in', 'Check-in',
              'OP-OTHER'),
          MenuProblem('p-4-8-2', 'Servicii pasageri — Control securitate',
              'Control securitate', 'OP-OTHER'),
          MenuProblem('p-4-8-3', 'Servicii pasageri — Îmbarcare', 'Îmbarcare',
              'OP-OTHER'),
          MenuProblem('p-4-8-4', 'Servicii pasageri — Platformă', 'Platformă',
              'OP-OTHER'),
          MenuProblem(
              'p-4-8-5', 'Servicii pasageri — Pistă', 'Pistă', 'OP-OTHER'),
          MenuProblem(
              'p-4-8-6', 'Servicii pasageri — Parcare', 'Parcare', 'OP-OTHER'),
          MenuProblem(
              'p-4-8-7', 'Servicii pasageri — Poartă', 'Poartă', 'OP-OTHER'),
          MenuProblem('p-4-8-8', 'Servicii pasageri — Terminal', 'Terminal',
              'OP-OTHER'),
        ],
      ),
    ],
  ),
  MenuCategory(
    'cat-5',
    'Ground handling și rampă',
    Icons.local_shipping_outlined,
    <MenuSubcategory>[
      MenuSubcategory(
        'sub-5-1',
        'Alimentare cu combustibil',
        <MenuProblem>[
          MenuProblem('p-5-1-1', 'Alimentare cu combustibil — Stand', 'Stand',
              'SF-SPILL'),
          MenuProblem('p-5-1-2', 'Alimentare cu combustibil — Platformă',
              'Platformă', 'SF-SPILL'),
          MenuProblem('p-5-1-3', 'Alimentare cu combustibil — Pistă', 'Pistă',
              'SF-SPILL'),
          MenuProblem('p-5-1-4', 'Alimentare cu combustibil — Cargo', 'Cargo',
              'SF-SPILL'),
          MenuProblem('p-5-1-5', 'Alimentare cu combustibil — Hangar', 'Hangar',
              'SF-SPILL'),
          MenuProblem('p-5-1-6', 'Alimentare cu combustibil — Poartă', 'Poartă',
              'SF-SPILL'),
          MenuProblem('p-5-1-7', 'Alimentare cu combustibil — Parcare',
              'Parcare', 'SF-SPILL'),
          MenuProblem('p-5-1-8', 'Alimentare cu combustibil — Terminal',
              'Terminal', 'SF-SPILL'),
        ],
      ),
      MenuSubcategory(
        'sub-5-2',
        'Degivrare',
        <MenuProblem>[
          MenuProblem('p-5-2-1', 'Degivrare — Stand', 'Stand', 'SF-SPILL'),
          MenuProblem(
              'p-5-2-2', 'Degivrare — Platformă', 'Platformă', 'SF-SPILL'),
          MenuProblem('p-5-2-3', 'Degivrare — Pistă', 'Pistă', 'SF-SPILL'),
          MenuProblem('p-5-2-4', 'Degivrare — Cargo', 'Cargo', 'SF-SPILL'),
          MenuProblem('p-5-2-5', 'Degivrare — Hangar', 'Hangar', 'SF-SPILL'),
          MenuProblem('p-5-2-6', 'Degivrare — Poartă', 'Poartă', 'SF-SPILL'),
          MenuProblem('p-5-2-7', 'Degivrare — Parcare', 'Parcare', 'SF-SPILL'),
          MenuProblem(
              'p-5-2-8', 'Degivrare — Terminal', 'Terminal', 'SF-SPILL'),
        ],
      ),
      MenuSubcategory(
        'sub-5-3',
        'Încărcare și balans',
        <MenuProblem>[
          MenuProblem(
              'p-5-3-1', 'Încărcare și balans — Stand', 'Stand', 'OP-OTHER'),
          MenuProblem('p-5-3-2', 'Încărcare și balans — Platformă', 'Platformă',
              'OP-OTHER'),
          MenuProblem(
              'p-5-3-3', 'Încărcare și balans — Pistă', 'Pistă', 'OP-OTHER'),
          MenuProblem(
              'p-5-3-4', 'Încărcare și balans — Cargo', 'Cargo', 'OP-OTHER'),
          MenuProblem(
              'p-5-3-5', 'Încărcare și balans — Hangar', 'Hangar', 'OP-OTHER'),
          MenuProblem(
              'p-5-3-6', 'Încărcare și balans — Poartă', 'Poartă', 'OP-OTHER'),
          MenuProblem('p-5-3-7', 'Încărcare și balans — Parcare', 'Parcare',
              'OP-OTHER'),
          MenuProblem('p-5-3-8', 'Încărcare și balans — Terminal', 'Terminal',
              'OP-OTHER'),
        ],
      ),
      MenuSubcategory(
        'sub-5-4',
        'Pushback și remorcare',
        <MenuProblem>[
          MenuProblem(
              'p-5-4-1', 'Pushback și remorcare — Stand', 'Stand', 'OP-OTHER'),
          MenuProblem('p-5-4-2', 'Pushback și remorcare — Platformă',
              'Platformă', 'OP-OTHER'),
          MenuProblem(
              'p-5-4-3', 'Pushback și remorcare — Pistă', 'Pistă', 'OP-OTHER'),
          MenuProblem(
              'p-5-4-4', 'Pushback și remorcare — Cargo', 'Cargo', 'OP-OTHER'),
          MenuProblem('p-5-4-5', 'Pushback și remorcare — Hangar', 'Hangar',
              'OP-OTHER'),
          MenuProblem('p-5-4-6', 'Pushback și remorcare — Poartă', 'Poartă',
              'OP-OTHER'),
          MenuProblem('p-5-4-7', 'Pushback și remorcare — Parcare', 'Parcare',
              'OP-OTHER'),
          MenuProblem('p-5-4-8', 'Pushback și remorcare — Terminal', 'Terminal',
              'OP-OTHER'),
        ],
      ),
      MenuSubcategory(
        'sub-5-5',
        'Echipamente GSE',
        <MenuProblem>[
          MenuProblem(
              'p-5-5-1', 'Echipamente GSE — Stand', 'Stand', 'SF-EQUIP'),
          MenuProblem('p-5-5-2', 'Echipamente GSE — Platformă', 'Platformă',
              'SF-EQUIP'),
          MenuProblem(
              'p-5-5-3', 'Echipamente GSE — Pistă', 'Pistă', 'SF-EQUIP'),
          MenuProblem(
              'p-5-5-4', 'Echipamente GSE — Cargo', 'Cargo', 'SF-EQUIP'),
          MenuProblem(
              'p-5-5-5', 'Echipamente GSE — Hangar', 'Hangar', 'SF-EQUIP'),
          MenuProblem(
              'p-5-5-6', 'Echipamente GSE — Poartă', 'Poartă', 'SF-EQUIP'),
          MenuProblem(
              'p-5-5-7', 'Echipamente GSE — Parcare', 'Parcare', 'SF-EQUIP'),
          MenuProblem(
              'p-5-5-8', 'Echipamente GSE — Terminal', 'Terminal', 'SF-EQUIP'),
        ],
      ),
      MenuSubcategory(
        'sub-5-6',
        'Coliziuni pe rampă',
        <MenuProblem>[
          MenuProblem(
              'p-5-6-1', 'Coliziuni pe rampă — Stand', 'Stand', 'OP-OTHER'),
          MenuProblem('p-5-6-2', 'Coliziuni pe rampă — Platformă', 'Platformă',
              'OP-OTHER'),
          MenuProblem(
              'p-5-6-3', 'Coliziuni pe rampă — Pistă', 'Pistă', 'OP-OTHER'),
          MenuProblem(
              'p-5-6-4', 'Coliziuni pe rampă — Cargo', 'Cargo', 'OP-OTHER'),
          MenuProblem(
              'p-5-6-5', 'Coliziuni pe rampă — Hangar', 'Hangar', 'OP-OTHER'),
          MenuProblem(
              'p-5-6-6', 'Coliziuni pe rampă — Poartă', 'Poartă', 'OP-OTHER'),
          MenuProblem(
              'p-5-6-7', 'Coliziuni pe rampă — Parcare', 'Parcare', 'OP-OTHER'),
          MenuProblem('p-5-6-8', 'Coliziuni pe rampă — Terminal', 'Terminal',
              'OP-OTHER'),
        ],
      ),
      MenuSubcategory(
        'sub-5-7',
        'Mărfuri periculoase',
        <MenuProblem>[
          MenuProblem(
              'p-5-7-1', 'Mărfuri periculoase — Stand', 'Stand', 'SF-SPILL'),
          MenuProblem('p-5-7-2', 'Mărfuri periculoase — Platformă', 'Platformă',
              'SF-SPILL'),
          MenuProblem(
              'p-5-7-3', 'Mărfuri periculoase — Pistă', 'Pistă', 'SF-SPILL'),
          MenuProblem(
              'p-5-7-4', 'Mărfuri periculoase — Cargo', 'Cargo', 'SF-SPILL'),
          MenuProblem(
              'p-5-7-5', 'Mărfuri periculoase — Hangar', 'Hangar', 'SF-SPILL'),
          MenuProblem(
              'p-5-7-6', 'Mărfuri periculoase — Poartă', 'Poartă', 'SF-SPILL'),
          MenuProblem('p-5-7-7', 'Mărfuri periculoase — Parcare', 'Parcare',
              'SF-SPILL'),
          MenuProblem('p-5-7-8', 'Mărfuri periculoase — Terminal', 'Terminal',
              'SF-SPILL'),
        ],
      ),
      MenuSubcategory(
        'sub-5-8',
        'Servire aeronavă',
        <MenuProblem>[
          MenuProblem(
              'p-5-8-1', 'Servire aeronavă — Stand', 'Stand', 'OP-OTHER'),
          MenuProblem('p-5-8-2', 'Servire aeronavă — Platformă', 'Platformă',
              'OP-OTHER'),
          MenuProblem(
              'p-5-8-3', 'Servire aeronavă — Pistă', 'Pistă', 'OP-OTHER'),
          MenuProblem(
              'p-5-8-4', 'Servire aeronavă — Cargo', 'Cargo', 'OP-OTHER'),
          MenuProblem(
              'p-5-8-5', 'Servire aeronavă — Hangar', 'Hangar', 'OP-OTHER'),
          MenuProblem(
              'p-5-8-6', 'Servire aeronavă — Poartă', 'Poartă', 'OP-OTHER'),
          MenuProblem(
              'p-5-8-7', 'Servire aeronavă — Parcare', 'Parcare', 'OP-OTHER'),
          MenuProblem(
              'p-5-8-8', 'Servire aeronavă — Terminal', 'Terminal', 'OP-OTHER'),
        ],
      ),
    ],
  ),
  MenuCategory(
    'cat-6',
    'Aeronave și tehnic',
    Icons.flight,
    <MenuSubcategory>[
      MenuSubcategory(
        'sub-6-1',
        'Motor și APU',
        <MenuProblem>[
          MenuProblem('p-6-1-1', 'Motor și APU — Pistă', 'Pistă', 'SF-FIRE'),
          MenuProblem(
              'p-6-1-2', 'Motor și APU — Platformă', 'Platformă', 'SF-FIRE'),
          MenuProblem('p-6-1-3', 'Motor și APU — Hangar', 'Hangar', 'SF-FIRE'),
          MenuProblem('p-6-1-4', 'Motor și APU — Poartă', 'Poartă', 'SF-FIRE'),
          MenuProblem('p-6-1-5', 'Motor și APU — Cargo', 'Cargo', 'SF-FIRE'),
          MenuProblem(
              'p-6-1-6', 'Motor și APU — Terminal', 'Terminal', 'SF-FIRE'),
          MenuProblem(
              'p-6-1-7', 'Motor și APU — Parcare', 'Parcare', 'SF-FIRE'),
          MenuProblem('p-6-1-8', 'Motor și APU — Stand', 'Stand', 'SF-FIRE'),
        ],
      ),
      MenuSubcategory(
        'sub-6-2',
        'Hidraulic și combustibil',
        <MenuProblem>[
          MenuProblem('p-6-2-1', 'Hidraulic și combustibil — Pistă', 'Pistă',
              'SF-SPILL'),
          MenuProblem('p-6-2-2', 'Hidraulic și combustibil — Platformă',
              'Platformă', 'SF-SPILL'),
          MenuProblem('p-6-2-3', 'Hidraulic și combustibil — Hangar', 'Hangar',
              'SF-SPILL'),
          MenuProblem('p-6-2-4', 'Hidraulic și combustibil — Poartă', 'Poartă',
              'SF-SPILL'),
          MenuProblem('p-6-2-5', 'Hidraulic și combustibil — Cargo', 'Cargo',
              'SF-SPILL'),
          MenuProblem('p-6-2-6', 'Hidraulic și combustibil — Terminal',
              'Terminal', 'SF-SPILL'),
          MenuProblem('p-6-2-7', 'Hidraulic și combustibil — Parcare',
              'Parcare', 'SF-SPILL'),
          MenuProblem('p-6-2-8', 'Hidraulic și combustibil — Stand', 'Stand',
              'SF-SPILL'),
        ],
      ),
      MenuSubcategory(
        'sub-6-3',
        'Cabină și presurizare',
        <MenuProblem>[
          MenuProblem(
              'p-6-3-1', 'Cabină și presurizare — Pistă', 'Pistă', 'SF-EQUIP'),
          MenuProblem('p-6-3-2', 'Cabină și presurizare — Platformă',
              'Platformă', 'SF-EQUIP'),
          MenuProblem('p-6-3-3', 'Cabină și presurizare — Hangar', 'Hangar',
              'SF-EQUIP'),
          MenuProblem('p-6-3-4', 'Cabină și presurizare — Poartă', 'Poartă',
              'SF-EQUIP'),
          MenuProblem(
              'p-6-3-5', 'Cabină și presurizare — Cargo', 'Cargo', 'SF-EQUIP'),
          MenuProblem('p-6-3-6', 'Cabină și presurizare — Terminal', 'Terminal',
              'SF-EQUIP'),
          MenuProblem('p-6-3-7', 'Cabină și presurizare — Parcare', 'Parcare',
              'SF-EQUIP'),
          MenuProblem(
              'p-6-3-8', 'Cabină și presurizare — Stand', 'Stand', 'SF-EQUIP'),
        ],
      ),
      MenuSubcategory(
        'sub-6-4',
        'Tren de aterizare',
        <MenuProblem>[
          MenuProblem(
              'p-6-4-1', 'Tren de aterizare — Pistă', 'Pistă', 'OP-OTHER'),
          MenuProblem('p-6-4-2', 'Tren de aterizare — Platformă', 'Platformă',
              'OP-OTHER'),
          MenuProblem(
              'p-6-4-3', 'Tren de aterizare — Hangar', 'Hangar', 'OP-OTHER'),
          MenuProblem(
              'p-6-4-4', 'Tren de aterizare — Poartă', 'Poartă', 'OP-OTHER'),
          MenuProblem(
              'p-6-4-5', 'Tren de aterizare — Cargo', 'Cargo', 'OP-OTHER'),
          MenuProblem('p-6-4-6', 'Tren de aterizare — Terminal', 'Terminal',
              'OP-OTHER'),
          MenuProblem(
              'p-6-4-7', 'Tren de aterizare — Parcare', 'Parcare', 'OP-OTHER'),
          MenuProblem(
              'p-6-4-8', 'Tren de aterizare — Stand', 'Stand', 'OP-OTHER'),
        ],
      ),
      MenuSubcategory(
        'sub-6-5',
        'Structură și avarii',
        <MenuProblem>[
          MenuProblem(
              'p-6-5-1', 'Structură și avarii — Pistă', 'Pistă', 'OP-OTHER'),
          MenuProblem('p-6-5-2', 'Structură și avarii — Platformă', 'Platformă',
              'OP-OTHER'),
          MenuProblem(
              'p-6-5-3', 'Structură și avarii — Hangar', 'Hangar', 'OP-OTHER'),
          MenuProblem(
              'p-6-5-4', 'Structură și avarii — Poartă', 'Poartă', 'OP-OTHER'),
          MenuProblem(
              'p-6-5-5', 'Structură și avarii — Cargo', 'Cargo', 'OP-OTHER'),
          MenuProblem('p-6-5-6', 'Structură și avarii — Terminal', 'Terminal',
              'OP-OTHER'),
          MenuProblem('p-6-5-7', 'Structură și avarii — Parcare', 'Parcare',
              'OP-OTHER'),
          MenuProblem(
              'p-6-5-8', 'Structură și avarii — Stand', 'Stand', 'OP-OTHER'),
        ],
      ),
      MenuSubcategory(
        'sub-6-6',
        'Sisteme electrice',
        <MenuProblem>[
          MenuProblem(
              'p-6-6-1', 'Sisteme electrice — Pistă', 'Pistă', 'SF-EQUIP'),
          MenuProblem('p-6-6-2', 'Sisteme electrice — Platformă', 'Platformă',
              'SF-EQUIP'),
          MenuProblem(
              'p-6-6-3', 'Sisteme electrice — Hangar', 'Hangar', 'SF-EQUIP'),
          MenuProblem(
              'p-6-6-4', 'Sisteme electrice — Poartă', 'Poartă', 'SF-EQUIP'),
          MenuProblem(
              'p-6-6-5', 'Sisteme electrice — Cargo', 'Cargo', 'SF-EQUIP'),
          MenuProblem('p-6-6-6', 'Sisteme electrice — Terminal', 'Terminal',
              'SF-EQUIP'),
          MenuProblem(
              'p-6-6-7', 'Sisteme electrice — Parcare', 'Parcare', 'SF-EQUIP'),
          MenuProblem(
              'p-6-6-8', 'Sisteme electrice — Stand', 'Stand', 'SF-EQUIP'),
        ],
      ),
      MenuSubcategory(
        'sub-6-7',
        'FOD și păsări',
        <MenuProblem>[
          MenuProblem('p-6-7-1', 'FOD și păsări — Pistă', 'Pistă', 'SF-FOD'),
          MenuProblem(
              'p-6-7-2', 'FOD și păsări — Platformă', 'Platformă', 'SF-FOD'),
          MenuProblem('p-6-7-3', 'FOD și păsări — Hangar', 'Hangar', 'SF-FOD'),
          MenuProblem('p-6-7-4', 'FOD și păsări — Poartă', 'Poartă', 'SF-FOD'),
          MenuProblem('p-6-7-5', 'FOD și păsări — Cargo', 'Cargo', 'SF-FOD'),
          MenuProblem(
              'p-6-7-6', 'FOD și păsări — Terminal', 'Terminal', 'SF-FOD'),
          MenuProblem(
              'p-6-7-7', 'FOD și păsări — Parcare', 'Parcare', 'SF-FOD'),
          MenuProblem('p-6-7-8', 'FOD și păsări — Stand', 'Stand', 'SF-FOD'),
        ],
      ),
      MenuSubcategory(
        'sub-6-8',
        'Urgențe la bord',
        <MenuProblem>[
          MenuProblem('p-6-8-1', 'Urgențe la bord — Pistă', 'Pistă', 'SF-FIRE'),
          MenuProblem(
              'p-6-8-2', 'Urgențe la bord — Platformă', 'Platformă', 'SF-FIRE'),
          MenuProblem(
              'p-6-8-3', 'Urgențe la bord — Hangar', 'Hangar', 'SF-FIRE'),
          MenuProblem(
              'p-6-8-4', 'Urgențe la bord — Poartă', 'Poartă', 'SF-FIRE'),
          MenuProblem('p-6-8-5', 'Urgențe la bord — Cargo', 'Cargo', 'SF-FIRE'),
          MenuProblem(
              'p-6-8-6', 'Urgențe la bord — Terminal', 'Terminal', 'SF-FIRE'),
          MenuProblem(
              'p-6-8-7', 'Urgențe la bord — Parcare', 'Parcare', 'SF-FIRE'),
          MenuProblem('p-6-8-8', 'Urgențe la bord — Stand', 'Stand', 'SF-FIRE'),
        ],
      ),
    ],
  ),
  MenuCategory(
    'cat-7',
    'Pasageri și terminal',
    Icons.groups_2_outlined,
    <MenuSubcategory>[
      MenuSubcategory(
        'sub-7-1',
        'Urgență medicală',
        <MenuProblem>[
          MenuProblem(
              'p-7-1-1', 'Urgență medicală — Terminal', 'Terminal', 'OP-OTHER'),
          MenuProblem(
              'p-7-1-2', 'Urgență medicală — Check-in', 'Check-in', 'OP-OTHER'),
          MenuProblem('p-7-1-3', 'Urgență medicală — Control securitate',
              'Control securitate', 'OP-OTHER'),
          MenuProblem('p-7-1-4', 'Urgență medicală — Îmbarcare', 'Îmbarcare',
              'OP-OTHER'),
          MenuProblem(
              'p-7-1-5', 'Urgență medicală — Poartă', 'Poartă', 'OP-OTHER'),
          MenuProblem(
              'p-7-1-6', 'Urgență medicală — Lounge', 'Lounge', 'OP-OTHER'),
          MenuProblem(
              'p-7-1-7', 'Urgență medicală — Parcare', 'Parcare', 'OP-OTHER'),
          MenuProblem('p-7-1-8', 'Urgență medicală — Zona bagaje',
              'Zona bagaje', 'OP-OTHER'),
        ],
      ),
      MenuSubcategory(
        'sub-7-2',
        'Accesibilitate',
        <MenuProblem>[
          MenuProblem(
              'p-7-2-1', 'Accesibilitate — Terminal', 'Terminal', 'OP-OTHER'),
          MenuProblem(
              'p-7-2-2', 'Accesibilitate — Check-in', 'Check-in', 'OP-OTHER'),
          MenuProblem('p-7-2-3', 'Accesibilitate — Control securitate',
              'Control securitate', 'OP-OTHER'),
          MenuProblem(
              'p-7-2-4', 'Accesibilitate — Îmbarcare', 'Îmbarcare', 'OP-OTHER'),
          MenuProblem(
              'p-7-2-5', 'Accesibilitate — Poartă', 'Poartă', 'OP-OTHER'),
          MenuProblem(
              'p-7-2-6', 'Accesibilitate — Lounge', 'Lounge', 'OP-OTHER'),
          MenuProblem(
              'p-7-2-7', 'Accesibilitate — Parcare', 'Parcare', 'OP-OTHER'),
          MenuProblem('p-7-2-8', 'Accesibilitate — Zona bagaje', 'Zona bagaje',
              'OP-OTHER'),
        ],
      ),
      MenuSubcategory(
        'sub-7-3',
        'Bagaje pasageri',
        <MenuProblem>[
          MenuProblem(
              'p-7-3-1', 'Bagaje pasageri — Terminal', 'Terminal', 'SC-BAG'),
          MenuProblem(
              'p-7-3-2', 'Bagaje pasageri — Check-in', 'Check-in', 'SC-BAG'),
          MenuProblem('p-7-3-3', 'Bagaje pasageri — Control securitate',
              'Control securitate', 'SC-BAG'),
          MenuProblem(
              'p-7-3-4', 'Bagaje pasageri — Îmbarcare', 'Îmbarcare', 'SC-BAG'),
          MenuProblem(
              'p-7-3-5', 'Bagaje pasageri — Poartă', 'Poartă', 'SC-BAG'),
          MenuProblem(
              'p-7-3-6', 'Bagaje pasageri — Lounge', 'Lounge', 'SC-BAG'),
          MenuProblem(
              'p-7-3-7', 'Bagaje pasageri — Parcare', 'Parcare', 'SC-BAG'),
          MenuProblem('p-7-3-8', 'Bagaje pasageri — Zona bagaje', 'Zona bagaje',
              'SC-BAG'),
        ],
      ),
      MenuSubcategory(
        'sub-7-4',
        'Copii și persoane dispărute',
        <MenuProblem>[
          MenuProblem('p-7-4-1', 'Copii și persoane dispărute — Terminal',
              'Terminal', 'OP-OTHER'),
          MenuProblem('p-7-4-2', 'Copii și persoane dispărute — Check-in',
              'Check-in', 'OP-OTHER'),
          MenuProblem(
              'p-7-4-3',
              'Copii și persoane dispărute — Control securitate',
              'Control securitate',
              'OP-OTHER'),
          MenuProblem('p-7-4-4', 'Copii și persoane dispărute — Îmbarcare',
              'Îmbarcare', 'OP-OTHER'),
          MenuProblem('p-7-4-5', 'Copii și persoane dispărute — Poartă',
              'Poartă', 'OP-OTHER'),
          MenuProblem('p-7-4-6', 'Copii și persoane dispărute — Lounge',
              'Lounge', 'OP-OTHER'),
          MenuProblem('p-7-4-7', 'Copii și persoane dispărute — Parcare',
              'Parcare', 'OP-OTHER'),
          MenuProblem('p-7-4-8', 'Copii și persoane dispărute — Zona bagaje',
              'Zona bagaje', 'OP-OTHER'),
        ],
      ),
      MenuSubcategory(
        'sub-7-5',
        'Comportament',
        <MenuProblem>[
          MenuProblem(
              'p-7-5-1', 'Comportament — Terminal', 'Terminal', 'SC-BEHAV'),
          MenuProblem(
              'p-7-5-2', 'Comportament — Check-in', 'Check-in', 'SC-BEHAV'),
          MenuProblem('p-7-5-3', 'Comportament — Control securitate',
              'Control securitate', 'SC-BEHAV'),
          MenuProblem(
              'p-7-5-4', 'Comportament — Îmbarcare', 'Îmbarcare', 'SC-BEHAV'),
          MenuProblem('p-7-5-5', 'Comportament — Poartă', 'Poartă', 'SC-BEHAV'),
          MenuProblem('p-7-5-6', 'Comportament — Lounge', 'Lounge', 'SC-BEHAV'),
          MenuProblem(
              'p-7-5-7', 'Comportament — Parcare', 'Parcare', 'SC-BEHAV'),
          MenuProblem('p-7-5-8', 'Comportament — Zona bagaje', 'Zona bagaje',
              'SC-BEHAV'),
        ],
      ),
      MenuSubcategory(
        'sub-7-6',
        'Îmbarcare',
        <MenuProblem>[
          MenuProblem(
              'p-7-6-1', 'Îmbarcare — Terminal', 'Terminal', 'OP-QUEUE'),
          MenuProblem(
              'p-7-6-2', 'Îmbarcare — Check-in', 'Check-in', 'OP-QUEUE'),
          MenuProblem('p-7-6-3', 'Îmbarcare — Control securitate',
              'Control securitate', 'OP-QUEUE'),
          MenuProblem(
              'p-7-6-4', 'Îmbarcare — Îmbarcare', 'Îmbarcare', 'OP-QUEUE'),
          MenuProblem('p-7-6-5', 'Îmbarcare — Poartă', 'Poartă', 'OP-QUEUE'),
          MenuProblem('p-7-6-6', 'Îmbarcare — Lounge', 'Lounge', 'OP-QUEUE'),
          MenuProblem('p-7-6-7', 'Îmbarcare — Parcare', 'Parcare', 'OP-QUEUE'),
          MenuProblem(
              'p-7-6-8', 'Îmbarcare — Zona bagaje', 'Zona bagaje', 'OP-QUEUE'),
        ],
      ),
      MenuSubcategory(
        'sub-7-7',
        'Facilități terminal',
        <MenuProblem>[
          MenuProblem('p-7-7-1', 'Facilități terminal — Terminal', 'Terminal',
              'SF-EQUIP'),
          MenuProblem('p-7-7-2', 'Facilități terminal — Check-in', 'Check-in',
              'SF-EQUIP'),
          MenuProblem('p-7-7-3', 'Facilități terminal — Control securitate',
              'Control securitate', 'SF-EQUIP'),
          MenuProblem('p-7-7-4', 'Facilități terminal — Îmbarcare', 'Îmbarcare',
              'SF-EQUIP'),
          MenuProblem(
              'p-7-7-5', 'Facilități terminal — Poartă', 'Poartă', 'SF-EQUIP'),
          MenuProblem(
              'p-7-7-6', 'Facilități terminal — Lounge', 'Lounge', 'SF-EQUIP'),
          MenuProblem('p-7-7-7', 'Facilități terminal — Parcare', 'Parcare',
              'SF-EQUIP'),
          MenuProblem('p-7-7-8', 'Facilități terminal — Zona bagaje',
              'Zona bagaje', 'SF-EQUIP'),
        ],
      ),
      MenuSubcategory(
        'sub-7-8',
        'Informare și anunțuri',
        <MenuProblem>[
          MenuProblem('p-7-8-1', 'Informare și anunțuri — Terminal', 'Terminal',
              'OP-IT'),
          MenuProblem('p-7-8-2', 'Informare și anunțuri — Check-in', 'Check-in',
              'OP-IT'),
          MenuProblem('p-7-8-3', 'Informare și anunțuri — Control securitate',
              'Control securitate', 'OP-IT'),
          MenuProblem('p-7-8-4', 'Informare și anunțuri — Îmbarcare',
              'Îmbarcare', 'OP-IT'),
          MenuProblem(
              'p-7-8-5', 'Informare și anunțuri — Poartă', 'Poartă', 'OP-IT'),
          MenuProblem(
              'p-7-8-6', 'Informare și anunțuri — Lounge', 'Lounge', 'OP-IT'),
          MenuProblem(
              'p-7-8-7', 'Informare și anunțuri — Parcare', 'Parcare', 'OP-IT'),
          MenuProblem('p-7-8-8', 'Informare și anunțuri — Zona bagaje',
              'Zona bagaje', 'OP-IT'),
        ],
      ),
    ],
  ),
  MenuCategory(
    'cat-8',
    'Mediu și meteo',
    Icons.cloud_outlined,
    <MenuSubcategory>[
      MenuSubcategory(
        'sub-8-1',
        'Vreme severă',
        <MenuProblem>[
          MenuProblem('p-8-1-1', 'Vreme severă — Pistă', 'Pistă', 'OP-OTHER'),
          MenuProblem(
              'p-8-1-2', 'Vreme severă — Platformă', 'Platformă', 'OP-OTHER'),
          MenuProblem(
              'p-8-1-3', 'Vreme severă — Terminal', 'Terminal', 'OP-OTHER'),
          MenuProblem(
              'p-8-1-4', 'Vreme severă — Parcare', 'Parcare', 'OP-OTHER'),
          MenuProblem('p-8-1-5', 'Vreme severă — Cargo', 'Cargo', 'OP-OTHER'),
          MenuProblem('p-8-1-6', 'Vreme severă — Hangar', 'Hangar', 'OP-OTHER'),
          MenuProblem('p-8-1-7', 'Vreme severă — Turn', 'Turn', 'OP-OTHER'),
          MenuProblem('p-8-1-8', 'Vreme severă — Împrejurimi', 'Împrejurimi',
              'OP-OTHER'),
        ],
      ),
      MenuSubcategory(
        'sub-8-2',
        'Zăpadă și gheață',
        <MenuProblem>[
          MenuProblem(
              'p-8-2-1', 'Zăpadă și gheață — Pistă', 'Pistă', 'OP-OTHER'),
          MenuProblem('p-8-2-2', 'Zăpadă și gheață — Platformă', 'Platformă',
              'OP-OTHER'),
          MenuProblem(
              'p-8-2-3', 'Zăpadă și gheață — Terminal', 'Terminal', 'OP-OTHER'),
          MenuProblem(
              'p-8-2-4', 'Zăpadă și gheață — Parcare', 'Parcare', 'OP-OTHER'),
          MenuProblem(
              'p-8-2-5', 'Zăpadă și gheață — Cargo', 'Cargo', 'OP-OTHER'),
          MenuProblem(
              'p-8-2-6', 'Zăpadă și gheață — Hangar', 'Hangar', 'OP-OTHER'),
          MenuProblem('p-8-2-7', 'Zăpadă și gheață — Turn', 'Turn', 'OP-OTHER'),
          MenuProblem('p-8-2-8', 'Zăpadă și gheață — Împrejurimi',
              'Împrejurimi', 'OP-OTHER'),
        ],
      ),
      MenuSubcategory(
        'sub-8-3',
        'Inundații',
        <MenuProblem>[
          MenuProblem('p-8-3-1', 'Inundații — Pistă', 'Pistă', 'SF-SPILL'),
          MenuProblem(
              'p-8-3-2', 'Inundații — Platformă', 'Platformă', 'SF-SPILL'),
          MenuProblem(
              'p-8-3-3', 'Inundații — Terminal', 'Terminal', 'SF-SPILL'),
          MenuProblem('p-8-3-4', 'Inundații — Parcare', 'Parcare', 'SF-SPILL'),
          MenuProblem('p-8-3-5', 'Inundații — Cargo', 'Cargo', 'SF-SPILL'),
          MenuProblem('p-8-3-6', 'Inundații — Hangar', 'Hangar', 'SF-SPILL'),
          MenuProblem('p-8-3-7', 'Inundații — Turn', 'Turn', 'SF-SPILL'),
          MenuProblem(
              'p-8-3-8', 'Inundații — Împrejurimi', 'Împrejurimi', 'SF-SPILL'),
        ],
      ),
      MenuSubcategory(
        'sub-8-4',
        'Vânt și jet blast',
        <MenuProblem>[
          MenuProblem(
              'p-8-4-1', 'Vânt și jet blast — Pistă', 'Pistă', 'OP-OTHER'),
          MenuProblem('p-8-4-2', 'Vânt și jet blast — Platformă', 'Platformă',
              'OP-OTHER'),
          MenuProblem('p-8-4-3', 'Vânt și jet blast — Terminal', 'Terminal',
              'OP-OTHER'),
          MenuProblem(
              'p-8-4-4', 'Vânt și jet blast — Parcare', 'Parcare', 'OP-OTHER'),
          MenuProblem(
              'p-8-4-5', 'Vânt și jet blast — Cargo', 'Cargo', 'OP-OTHER'),
          MenuProblem(
              'p-8-4-6', 'Vânt și jet blast — Hangar', 'Hangar', 'OP-OTHER'),
          MenuProblem(
              'p-8-4-7', 'Vânt și jet blast — Turn', 'Turn', 'OP-OTHER'),
          MenuProblem('p-8-4-8', 'Vânt și jet blast — Împrejurimi',
              'Împrejurimi', 'OP-OTHER'),
        ],
      ),
      MenuSubcategory(
        'sub-8-5',
        'Păsări și animale',
        <MenuProblem>[
          MenuProblem(
              'p-8-5-1', 'Păsări și animale — Pistă', 'Pistă', 'SF-FOD'),
          MenuProblem('p-8-5-2', 'Păsări și animale — Platformă', 'Platformă',
              'SF-FOD'),
          MenuProblem(
              'p-8-5-3', 'Păsări și animale — Terminal', 'Terminal', 'SF-FOD'),
          MenuProblem(
              'p-8-5-4', 'Păsări și animale — Parcare', 'Parcare', 'SF-FOD'),
          MenuProblem(
              'p-8-5-5', 'Păsări și animale — Cargo', 'Cargo', 'SF-FOD'),
          MenuProblem(
              'p-8-5-6', 'Păsări și animale — Hangar', 'Hangar', 'SF-FOD'),
          MenuProblem('p-8-5-7', 'Păsări și animale — Turn', 'Turn', 'SF-FOD'),
          MenuProblem('p-8-5-8', 'Păsări și animale — Împrejurimi',
              'Împrejurimi', 'SF-FOD'),
        ],
      ),
      MenuSubcategory(
        'sub-8-6',
        'Poluare și scurgeri',
        <MenuProblem>[
          MenuProblem(
              'p-8-6-1', 'Poluare și scurgeri — Pistă', 'Pistă', 'SF-SPILL'),
          MenuProblem('p-8-6-2', 'Poluare și scurgeri — Platformă', 'Platformă',
              'SF-SPILL'),
          MenuProblem('p-8-6-3', 'Poluare și scurgeri — Terminal', 'Terminal',
              'SF-SPILL'),
          MenuProblem('p-8-6-4', 'Poluare și scurgeri — Parcare', 'Parcare',
              'SF-SPILL'),
          MenuProblem(
              'p-8-6-5', 'Poluare și scurgeri — Cargo', 'Cargo', 'SF-SPILL'),
          MenuProblem(
              'p-8-6-6', 'Poluare și scurgeri — Hangar', 'Hangar', 'SF-SPILL'),
          MenuProblem(
              'p-8-6-7', 'Poluare și scurgeri — Turn', 'Turn', 'SF-SPILL'),
          MenuProblem('p-8-6-8', 'Poluare și scurgeri — Împrejurimi',
              'Împrejurimi', 'SF-SPILL'),
        ],
      ),
      MenuSubcategory(
        'sub-8-7',
        'Zgomot și lumină',
        <MenuProblem>[
          MenuProblem(
              'p-8-7-1', 'Zgomot și lumină — Pistă', 'Pistă', 'SC-BEHAV'),
          MenuProblem('p-8-7-2', 'Zgomot și lumină — Platformă', 'Platformă',
              'SC-BEHAV'),
          MenuProblem(
              'p-8-7-3', 'Zgomot și lumină — Terminal', 'Terminal', 'SC-BEHAV'),
          MenuProblem(
              'p-8-7-4', 'Zgomot și lumină — Parcare', 'Parcare', 'SC-BEHAV'),
          MenuProblem(
              'p-8-7-5', 'Zgomot și lumină — Cargo', 'Cargo', 'SC-BEHAV'),
          MenuProblem(
              'p-8-7-6', 'Zgomot și lumină — Hangar', 'Hangar', 'SC-BEHAV'),
          MenuProblem('p-8-7-7', 'Zgomot și lumină — Turn', 'Turn', 'SC-BEHAV'),
          MenuProblem('p-8-7-8', 'Zgomot și lumină — Împrejurimi',
              'Împrejurimi', 'SC-BEHAV'),
        ],
      ),
      MenuSubcategory(
        'sub-8-8',
        'Vizibilitate și fum',
        <MenuProblem>[
          MenuProblem(
              'p-8-8-1', 'Vizibilitate și fum — Pistă', 'Pistă', 'SF-FIRE'),
          MenuProblem('p-8-8-2', 'Vizibilitate și fum — Platformă', 'Platformă',
              'SF-FIRE'),
          MenuProblem('p-8-8-3', 'Vizibilitate și fum — Terminal', 'Terminal',
              'SF-FIRE'),
          MenuProblem(
              'p-8-8-4', 'Vizibilitate și fum — Parcare', 'Parcare', 'SF-FIRE'),
          MenuProblem(
              'p-8-8-5', 'Vizibilitate și fum — Cargo', 'Cargo', 'SF-FIRE'),
          MenuProblem(
              'p-8-8-6', 'Vizibilitate și fum — Hangar', 'Hangar', 'SF-FIRE'),
          MenuProblem(
              'p-8-8-7', 'Vizibilitate și fum — Turn', 'Turn', 'SF-FIRE'),
          MenuProblem('p-8-8-8', 'Vizibilitate și fum — Împrejurimi',
              'Împrejurimi', 'SF-FIRE'),
        ],
      ),
    ],
  ),
];

const int menuProblemCount = 512;
