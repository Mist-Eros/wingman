# Craiova airport zones (used by the AI location extractor + UI)

The demo is set at **Aeroportul Internațional Craiova (CRA / LRCV)**. Locations are
free text in the app and on the PC dashboard; the backend extracts a zone from the
sentence, and the app's local brain recognises the same words offline.

## From the map (OpenStreetMap data)

Queried around `44.318889, 23.886389` ([OSM map](https://www.openstreetmap.org/search?query=44.318889%2C23.886389)):

| Zone | OSM tag / name |
|---|---|
| **Terminal 2** | `Terminalul 2 al Aeroportului Internațional Craiova` (`aeroway=terminal`) |
| **Platforma CRA** | apron |
| **Pistă 09/27** | runway `09/27` |
| Taxiways, hangars, helipads | `aeroway=taxiway`, `aeroway=hangar`, `aeroway=helipad` |
| Parking areas | 4 × `amenity=parking` (one named `Parcare`) |

Official airport site (for the passenger-flow areas): [aeroportcraiova.ro](https://aeroportcraiova.ro/)
— sections *Controlul de Securitate*, *Vama*, *Tarife Parcare*.

## Zone catalog used by Wingman

Entrances / exits and landside:
- `Intrarea principală`, `Ieșirea principală`
- `Parcare`, `Parcare scurtă durată`, `Parcare lungă durată`, `Parcare taxi / bus`
- `Terminal 1`, `Terminal 2`, `Terminal Sosiri`, `Terminal Plecări`, `Terminal Cargo`

Passenger flow / airside:
- `Check-in`, `Control securitate`, `Vamă`, `Sala de îmbarcare`, `Zona de îmbarcare`
- `Poarta 1…N`, `Bandă de bagaje 1…N`, `Zona bagaje`, `Terasă / zonă publică`
- `Platformă`, `Stand 1…8` (apron), `Pistă 09/27`, `Turn de control`, `Hangar`

Anything addressed like `terminal 2`, `poarta 3`, `banda 1`, `stand 4`, `sector 2`,
`parcare P2` is also parsed as a numbered location.

## Behaviour

- A report with any recognised zone (e.g. **„a luat foc un calculator la intrare”**)
  is **dispatched directly** — no “where?” or “is anyone hurt?” question.
- The only question left is for a completely unknown location (`„unde se întâmplă exact?”`)
  and for an unknown incident type.
- The PC dashboard report form has a single “Zonă / locație” field (no dropdowns, no quick chips);
  if it is left empty, the server extracts the zone from the sentence. The mobile app accepts
  the same words by voice or typed text.

