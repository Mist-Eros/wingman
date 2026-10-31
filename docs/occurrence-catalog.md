# Catalog de incidente aeroportuare (baza de date Wingman)

Bază de date cu incidentele posibile într-un aeroport, aliniată la cadrul european de raportare și la taxonomia ASRS. Fiecare intrare este mapată pe unul dintre cele **14 coduri operaționale** Wingman, ca să poată fi clasificată, dispecerizată și raportată.

**59 incidente** · **8 categorii** · **55** marcate ca obligatoriu de raportat în UE (Reg. 2015/1018).

> Sursa de adevăr pentru aplicație este `backend/app/data/occurrences.json`; acest document este generat din ea. Nu edita tabelul manual — rulează `python scripts/render_occurrence_catalog.py` după modificarea JSON-ului.

## Surse

- **Commission Implementing Regulation (EU) 2015/1018 — list of occurrences to be mandatorily reported** — <https://www.legislation.gov.uk/eur/2015/1018>
- **Regulation (EU) No 376/2014 on the reporting, analysis and follow-up of occurrences in civil aviation** — <https://eur-lex.europa.eu/legal-content/EN/TXT/?uri=CELEX:32014R0376>
- **NASA Aviation Safety Reporting System — database** — <https://asrs.arc.nasa.gov/search/database.html>
- **ASRS Coding Taxonomy (April 2024)** — <https://asrs.arc.nasa.gov/docs/dbol/ASRS_CodingTaxonomy.pdf>
- **Belgium — Manual for Reporting Occurrences in Ground Handling (V2025-01-08)** — <https://mobilit.belgium.be/sites/default/files/documents/publications/2025/GH_Manual_Reporting%20Occurrences_V20250108.pdf>
- **EASA — list classifying occurrences in civil aviation to be mandatorily reported** — <https://www.easa.europa.eu/en/regulations/list-classifying-occurrences-civil-aviation-be-mandatorily-reported-according-regulation-eu-no>
- **SKYbrary — Regulation 2015/1018 occurrences to be mandatorily reported** — <https://skybrary.aero/articles/regulation-20151018-occurrences-civil-aviation-be-mandatorily-reported>

## Cum se leagă de Wingman

Wingman rămâne cu un classifier închis de 14 coduri (modelul local mic are nevoie de puține clase). Catalogul adaugă profunzime și acoperire: fiecare incident posibil este descris, exemplificat și mapat pe codul operațional corespunzător, iar API-ul îl poate servi ca referință pentru interfață, antrenare și raportare.

| Domeniu | Incidente | Coduri operaționale folosite |
|---|---:|---|
| Mișcare aeronave și pistă | 8 | `OP-OTHER, SC-ACCESS, SF-FOD` |
| Terminal și pasageri | 11 | `OP-OTHER, OP-QUEUE, SC-BAG, SC-BEHAV, SC-ITEM, SF-EQUIP, SF-FIRE, SF-SPILL` |
| Servicii și infrastructură | 14 | `MT-BELT, MT-ESC, MT-JBRIDGE, OP-IT, OP-OTHER, SF-EQUIP` |
| Ground handling și rampă | 9 | `OP-OTHER, SC-ACCESS, SF-EQUIP, SF-SPILL` |
| Aeronavă și tehnic | 8 | `OP-OTHER, SF-EQUIP, SF-FIRE, SF-SPILL` |
| Securitate | 6 | `SC-ACCESS, SC-BAG, SC-BEHAV, SC-ITEM` |
| Mărfuri periculoase | 2 | `SC-ITEM, SF-SPILL` |
| Factor uman și mediu | 1 | `OP-OTHER` |

## Catalog

### Mișcare aeronave și pistă (8)

Referință: EU 2015/1018 Annex IV.1.1

| ID | Incident | Cod | Obligatoriu UE | Referință UE | Exemplu |
|---|---|---|---|---|---|
| OCC-001 | **Coliziune cu păsări sau animale pe aria de mișcare**<br>Bird or wildlife strike on the movement area | `SF-FOD` | da | EU 2015/1018 Annex IV.1.1(2), Annex I.5(4) | Un stol de păsări a trecut prin fața aeronavei la aterizare. |
| OCC-002 | **Corp străin pe pistă sau cale de rulare**<br>Foreign object debris on runway or taxiway | `SF-FOD` | da | EU 2015/1018 Annex IV.1.1(7), Annex I.5(5) | Bucăți de cauciuc și unelte pe calea de rulare A. |
| OCC-003 | **Incursiune pe pistă sau cale de rulare**<br>Runway or taxiway incursion | `SC-ACCESS` | da | EU 2015/1018 Annex IV.1.1(4), Annex I.3(2) | O mașină de întreținere a intrat pe pista 09 fără autorizație. |
| OCC-004 | **Excursie de pistă sau cale de rulare**<br>Runway or taxiway excursion | `OP-OTHER` | da | EU 2015/1018 Annex IV.1.1(3), Annex I.3(1) | Aeronava a ieșit cu roata din dreapta pe marginea pistei la aterizare. |
| OCC-005 | **Dronă / UAS în apropierea aeroportului**<br>Drone or UAS in the airport vicinity | `SC-ACCESS` | da | EU 2015/1018 Annex I.5(8), Annex IV.1.3(2) | O dronă zboară deasupra parcării, aproape de culoarul de apropiere. |
| OCC-006 | **Obstacol nemarcat pe aria de mișcare**<br>Unmarked obstacle on the movement area | `SF-FOD` | da | EU 2015/1018 Annex IV.1.1(8) | Un stâlp de iluminat nou nu apare pe nicio schemă și nu e marcat. |
| OCC-007 | **Jet blast, rotor wash sau suflu de elice**<br>Jet blast, rotor wash or propeller blast | `OP-OTHER` | da | EU 2015/1018 Annex IV.1.1(11), Annex I.4(8) | Un container a fost aruncat de jet blast lângă stand. |
| OCC-008 | **Coliziune la sol între aeronavă și vehicul/echipament**<br>Ground collision between aircraft and vehicle or equipment | `OP-OTHER` | da | EU 2015/1018 Annex IV.1.1(1), Annex IV.2.1(1) | Un vehicul de bagaje a lovit aripa stângă a aeronavei. |

### Terminal și pasageri (11)

Referință: EU 2015/1018 Annex IV.1.1–1.3

| ID | Incident | Cod | Obligatoriu UE | Referință UE | Exemplu |
|---|---|---|---|---|---|
| OCC-009 | **Incendiu în terminal**<br>Fire in the terminal | `SF-FIRE` | da | EU 2015/1018 Annex IV.1.3(1) | A luat foc un coș de gunoi lângă poarta 4. |
| OCC-010 | **Fum, miros de ars sau scânteieri**<br>Smoke, burning smell or arcing | `SF-FIRE` | da | EU 2015/1018 Annex IV.1.3(1), Annex II.3(16) | Miros de plastic ars lângă tabloul electric de la poarta 7. |
| OCC-011 | **Scurgere de lichid cu pericol de alunecare**<br>Liquid spill and slip hazard | `SF-SPILL` | nu | EU 2015/1018 Annex IV.1.3(1) (aerodrome facility safety) | S-a vărsat un lichid pe jos lângă poarta 3, e alunecos. |
| OCC-012 | **Inundație sau infiltrație de apă**<br>Flooding or water ingress | `SF-SPILL` | nu | EU 2015/1018 Annex IV.1.2(2) | S-a spart o conductă în zona de check-in și curge apă. |
| OCC-013 | **Bagaj nesupravegheat sau abandonat**<br>Unattended or abandoned baggage | `SC-BAG` | da | EU 2015/1018 Annex IV.1.3(2) | Am găsit un bagaj fără proprietar lângă banda de bagaje 3. |
| OCC-015 | **Obiect sau colet suspect**<br>Suspicious item or parcel | `SC-ITEM` | da | EU 2015/1018 Annex IV.1.3(2) | Un colet suspect a fost găsit sub un scaun în zona de așteptare. |
| OCC-017 | **Pasager turbulent, violent sau intoxicat**<br>Unruly, violent or intoxicated passenger | `SC-BEHAV` | da | EU 2015/1018 Annex I.6(2) | Un pasager beat amenință personalul de la poarta 6. |
| OCC-021 | **Aglomerare la controlul de securitate sau îmbarcare**<br>Congestion at security or boarding | `OP-QUEUE` | nu | EU 2015/1018 Annex IV.1.2 (service degradation) | Coada la controlul de securitate a ajuns până în zona de check-in. |
| OCC-022 | **Urgență medicală în terminal**<br>Medical emergency in the terminal | `OP-OTHER` | nu | EU 2015/1018 Annex I.4 (critical situation, medical assistance) | Un pasager a leșinat în zona de îmbarcare. |
| OCC-023 | **Evacuare de urgență**<br>Emergency evacuation | `OP-OTHER` | da | EU 2015/1018 Annex IV.1.1(12), Annex I.4(6) | S-a declanșat evacuarea terminalului din cauza unui fum dens. |
| OCC-024 | **Defecțiune structurală sau geam spart**<br>Structural defect or broken glass | `SF-EQUIP` | da | EU 2015/1018 Annex IV.1.2(2) | Un geam s-a spart în zona de plecări și cad bucăți. |

### Servicii și infrastructură (14)

Referință: EU 2015/1018 Annex III, IV.1.2

| ID | Incident | Cod | Obligatoriu UE | Referință UE | Exemplu |
|---|---|---|---|---|---|
| OCC-025 | **Defecțiune la escalator sau lift**<br>Escalator or lift failure | `MT-ESC` | da | EU 2015/1018 Annex IV.1.2(2) | Liftul din zona de sosiri este blocat între etaje. |
| OCC-026 | **Persoană blocată în lift sau escalator**<br>Person trapped in lift or escalator | `MT-ESC` | da | EU 2015/1018 Annex IV.1.2(2) | O persoană este blocată în liftul de la Terminal 2. |
| OCC-027 | **Defecțiune la jet bridge / pasarelă**<br>Jet bridge or boarding bridge failure | `MT-JBRIDGE` | da | EU 2015/1018 Annex IV.1.2(2) | Pasarela nu se retrage de la aeronavă și blochează poarta. |
| OCC-028 | **Jet bridge lovește aeronava**<br>Jet bridge collision with aircraft | `MT-JBRIDGE` | da | EU 2015/1018 Annex IV.2.3(12) | Pasarela a atins ușa aeronavei și a produs o avarie. |
| OCC-029 | **Bandă de bagaje blocată sau avariată**<br>Baggage belt jam or damage | `MT-BELT` | da | EU 2015/1018 Annex IV.1.2(2), Annex IV.2.3(10) | Banda de bagaje 3 s-a blocat cu un bagaj înțepenit. |
| OCC-030 | **Cădere IT / check-in / rețea**<br>IT, check-in or network outage | `OP-IT` | da | EU 2015/1018 Annex IV.1.2(2), Annex III.2(5) | Sistemul de check-in este picat pe toate pozițiile. |
| OCC-031 | **Pană de anunțuri, afișaje sau rețea**<br>PA, display or network failure | `OP-IT` | da | EU 2015/1018 Annex IV.1.2(1)(2) | Ecranele de plecări sunt negre și anunțurile nu se aud. |
| OCC-032 | **Incident cibernetic**<br>Cyber security incident | `OP-IT` | da | EU 2015/1018 Annex III.2(7), Annex IV.1.2(2) | Un post de lucru afișează un mesaj de ransomware. |
| OCC-033 | **Defecțiune iluminat, marcaj sau semnalizare**<br>Lighting, marking or signage failure | `SF-EQUIP` | da | EU 2015/1018 Annex IV.1.2(3) | Luminile de margine ale pistei 09 sunt stinse pe o porțiune. |
| OCC-034 | **Serviciul de pompieri/RFFS indisponibil**<br>Rescue and firefighting service unavailable | `SF-EQUIP` | da | EU 2015/1018 Annex IV.1.2(5) | Mașina principală de pompieri este defectă și nu poate interveni. |
| OCC-035 | **Defecțiunea sistemului de alertare de urgență**<br>Emergency alerting system failure | `SF-EQUIP` | da | EU 2015/1018 Annex IV.1.2(4) | Alarma de incendiu din terminal nu s-a auzit la test. |
| OCC-036 | **Pană de curent**<br>Power outage | `SF-EQUIP` | da | EU 2015/1018 Annex IV.1.2(2) | S-a luat curentul în terminalul de sosiri. |
| OCC-037 | **Pierderea comunicațiilor aeroport–ATS**<br>Loss of aerodrome–ATS communications | `OP-OTHER` | da | EU 2015/1018 Annex IV.1.2(1), Annex III.2(3) | Legătura radio cu turnul nu mai funcționează pe frecvența de sol. |
| OCC-038 | **Starea suprafeței pistei (zăpadă, gheață, apă)**<br>Runway surface condition (snow, ice, water) | `OP-OTHER` | da | EU 2015/1018 Annex IV.1.3(7), Annex I.5(6) | Pista 09 are gheață pe ultimii 300 de metri. |

### Ground handling și rampă (9)

Referință: EU 2015/1018 Annex IV.2

| ID | Incident | Cod | Obligatoriu UE | Referință UE | Exemplu |
|---|---|---|---|---|---|
| OCC-039 | **Coliziune între echipament de sol și aeronavă**<br>Ground support equipment collision with aircraft | `OP-OTHER` | da | EU 2015/1018 Annex IV.2.1(1), Annex IV.2.3(12) | Un tractor de bagaje a lovit fuselajul în timpul îmbarcării. |
| OCC-040 | **Scurgere de combustibil la alimentare**<br>Fuel spill during refuelling | `SF-SPILL` | da | EU 2015/1018 Annex IV.2.3(7), Annex IV.1.3(5) | S-a vărsat kerosen la cuplarea furtunului de alimentare. |
| OCC-041 | **Combustibil contaminat sau de tip greșit**<br>Contaminated or wrong fuel type | `SF-SPILL` | da | EU 2015/1018 Annex IV.2.3(9), Annex I.2.1(1) | În proba de combustibil a apărut apă și sedimente. |
| OCC-042 | **Degivrare/antigivrare inadecvată**<br>Inadequate de-icing or anti-icing | `SF-SPILL` | da | EU 2015/1018 Annex IV.2.3(11), Annex I.2.2(2) | Aripa dreaptă nu a fost degivrată complet înainte de plecare. |
| OCC-043 | **Eroare de încărcare sau balansare**<br>Loading or weight-and-balance error | `OP-OTHER` | da | EU 2015/1018 Annex IV.2.3(1) | Loadsheet-ul arată cu 400 kg mai puțin decât bagajele încărcate. |
| OCC-044 | **Neconcordanță bagaje–pasageri**<br>Baggage–passenger reconciliation error | `OP-OTHER` | da | EU 2015/1018 Annex IV.2.3(5) | Un bagaj a fost urcat, dar pasagerul nu s-a prezentat la poartă. |
| OCC-045 | **Avarie la pushback sau remorcare**<br>Damage during pushback or towing | `OP-OTHER` | da | EU 2015/1018 Annex IV.2.3(6), Annex IV.2.1(5) | Bara de remorcare s-a rupt în timpul pushback-ului. |
| OCC-046 | **Defecțiune echipament de sol (GPU, scară, bară)**<br>Ground support equipment defect (GPU, stairs, tow bar) | `SF-EQUIP` | da | EU 2015/1018 Annex IV.2.3(10) | Priza GPU are cablul deteriorat și face scurtcircuit. |
| OCC-047 | **Persoană neautorizată pe platformă**<br>Unauthorized person on the apron | `SC-ACCESS` | da | EU 2015/1018 Annex IV.1.1(10) | Un pasager a ieșit pe platformă prin ușa de serviciu. |

### Aeronavă și tehnic (8)

Referință: EU 2015/1018 Annex I–II

| ID | Incident | Cod | Obligatoriu UE | Referință UE | Exemplu |
|---|---|---|---|---|---|
| OCC-050 | **Incendiu la motor sau în aeronavă**<br>Engine or aircraft fire | `SF-FIRE` | da | EU 2015/1018 Annex I.4(2), Annex II.2 | Motorul stâng are flăcări la pornire. |
| OCC-051 | **Fum în cabină sau în cockpit**<br>Smoke in cabin or cockpit | `SF-FIRE` | da | EU 2015/1018 Annex I.4(3) | Echipajul raportează fum în cabina pasagerilor. |
| OCC-052 | **Scurgere hidraulică, ulei sau combustibil din aeronavă**<br>Hydraulic, oil or fuel leak from aircraft | `SF-SPILL` | da | EU 2015/1018 Annex I.2.1(4), Annex II.3(2) | Sub aeronavă apare o pată de lichid hidraulic. |
| OCC-053 | **Aterizare dură, tail strike sau lovire cu aripa**<br>Hard landing, tail strike or wingtip strike | `OP-OTHER` | da | EU 2015/1018 Annex I.3(7)(12) | Aeronava a atins pista cu coada la rotație. |
| OCC-054 | **Problemă de presurizare sau oxigen**<br>Pressurisation or oxygen problem | `SF-EQUIP` | da | EU 2015/1018 Annex I.4(7)(9) | Măștile de oxigen au căzut automat în cabină. |
| OCC-055 | **Declarare Mayday sau PAN PAN**<br>Mayday or PAN PAN declaration | `OP-OTHER` | da | EU 2015/1018 Annex I.4(1), Annex III.3(1) | Echipajul declară Mayday din cauza unui incendiu la bord. |
| OCC-056 | **Fulger, grindină sau turbulență severă**<br>Lightning, hail or severe turbulence | `OP-OTHER` | da | EU 2015/1018 Annex I.5(9)(10)(11)(12) | Aeronava a fost lovită de fulger și a pierdut un sistem electric. |
| OCC-058 | **Defect tehnic descoperit la mentenanță**<br>Technical defect found during maintenance | `OP-OTHER` | da | EU 2015/1018 Annex II.3 | La inspecție s-a găsit o fisură în trenul de aterizare. |

### Securitate (6)

Referință: EU 2015/1018 Annex I.6, IV.1.3

| ID | Incident | Cod | Obligatoriu UE | Referință UE | Exemplu |
|---|---|---|---|---|---|
| OCC-014 | **Bagaj suspect**<br>Suspicious baggage | `SC-BAG` | da | EU 2015/1018 Annex IV.1.3(2) | Un bagaj suspect, cu fire vizibile, este lăsat lângă poarta 2. |
| OCC-016 | **Armă, cuțit sau obiect interzis găsit**<br>Weapon or prohibited item found | `SC-ITEM` | da | EU 2015/1018 Annex IV.1.3(2) | La controlul de securitate a fost găsit un cuțit în bagajul de mână. |
| OCC-018 | **Amenințare cu bombă sau deturnare**<br>Bomb threat or hijack | `SC-BEHAV` | da | EU 2015/1018 Annex I.6(1) | Un apel anunță o bombă în terminalul de plecări. |
| OCC-019 | **Persoană neautorizată în zonă restricționată**<br>Unauthorized person in a restricted area | `SC-ACCESS` | da | EU 2015/1018 Annex IV.1.1(10), Annex IV.1.3(2) | O persoană fără legitimație se plimbă pe platformă. |
| OCC-020 | **Călător clandestin**<br>Stowaway | `SC-ACCESS` | da | EU 2015/1018 Annex I.6(3) | Un om a fost găsit ascuns în compartimentul de bagaje. |
| OCC-057 | **Interferență laser sau lumină puternică**<br>Laser or high-power light interference | `SC-BEHAV` | da | EU 2015/1018 Annex I.5(8), Annex III.3(3) | Un laser verde a fost îndreptat spre aeronava în apropiere. |

### Mărfuri periculoase (2)

Referință: EU 2015/1018 Annex I.1.1, IV.2.3

| ID | Incident | Cod | Obligatoriu UE | Referință UE | Exemplu |
|---|---|---|---|---|---|
| OCC-048 | **Mărfuri periculoase nedocumentate sau etichetate greșit**<br>Undeclared or incorrectly labelled dangerous goods | `SC-ITEM` | da | EU 2015/1018 Annex IV.2.3(4), Annex I.1.1(2) | Un colet conține baterii cu litiu fără etichetă de pericol. |
| OCC-049 | **Scurgere de substanță periculoasă**<br>Dangerous goods leak or spill | `SF-SPILL` | da | EU 2015/1018 Annex IV.2.3(4), Annex I.1.1(2) | Un bidon cu substanță corozivă s-a spart în zona cargo. |

### Factor uman și mediu (1)

Referință: EU 2015/1018 Annex I.1.5, I.5

| ID | Incident | Cod | Obligatoriu UE | Referință UE | Exemplu |
|---|---|---|---|---|---|
| OCC-059 | **Oboseală sau factor uman care afectează siguranța**<br>Fatigue or human performance affecting safety | `OP-OTHER` | da | EU 2015/1018 Annex I.1.5(3), Annex III.3(6), Annex IV.2.3(13) | Un operator obosit a uitat să închidă o barieră de acces. |

## Distribuție pe coduri operaționale

| Cod | Incidente |
|---|---:|
| `MT-BELT` | 1 |
| `MT-ESC` | 2 |
| `MT-JBRIDGE` | 2 |
| `OP-IT` | 3 |
| `OP-OTHER` | 16 |
| `OP-QUEUE` | 1 |
| `SC-ACCESS` | 5 |
| `SC-BAG` | 2 |
| `SC-BEHAV` | 3 |
| `SC-ITEM` | 3 |
| `SF-EQUIP` | 7 |
| `SF-FIRE` | 4 |
| `SF-FOD` | 3 |
| `SF-SPILL` | 7 |

## Cum adaugi un incident

1. Adaugă o intrare nouă în `backend/app/data/occurrences.json` (ID unic `OCC-...`, `app_code` existent, categorie existentă, `eu_ref`, `mandatory_eu`, aliasuri și un exemplu).
2. Rulează `python scripts/render_occurrence_catalog.py`.
3. Rulează `python scripts/smoke_test.py --base https://127.0.0.1:8443` — catalogul este validat la pornirea backend-ului și în smoke test.

## API
- `GET /api/occurrences` — tot catalogul (toate intrările + surse + categorii)
- `GET /api/occurrences?code=SF-FIRE` — filtrare pe cod operațional
- `GET /api/occurrences?category=ground_handling` — filtrare pe domeniu
- `GET /api/occurrences/{id}` — o singură intrare
