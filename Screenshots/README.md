# Wingman — screenshots (current set)

Capturi reale, făcute pe **31 octombrie 2026** după toate modificările de UI
(bară de raportare jos, fără fereastră de 5 s, coadă fără tichete închise,
card low alb, probabilitate Craiova). Setul vechi de design a fost șters.

## Structură

| Folder | Conținut |
|---|---|
| `Wingman/01_Login/` | login, roluri demo, sky adaptiv |
| `Wingman/02_Reporter/` | voce, meniu 8×8×8 pe 3 niveluri (4×2), tastare, verificare |
| `Wingman/03_Dispatcher/` | coadă live, istoric + Golește istoricul, card low-priority alb, mod demo, bara de raportare |
| `Wingman/04_Crew/` | coadă pe departament, Preia → tichet în lucru, vot |
| `Wingman/05_Notifications/` | notificare locală scoped pe departament |
| `Wingman/06_Desktop/` | control room Waterfox — admin view light (coadă live, istoric, formular raportare) |
| `Wingman/07_DevTools/` | DevTools (AI, STT, WSS, demo actions) |
| `Team/` | cardurile egale „cine a făcut ce” + `team-grid.png` |

## Carduri echipă

Fiecare card are **aceeași dimensiune (1600×1450)**, același șablon, 3 capturi
și aceleași secțiuni. Sursa: `Team/*.html` + generatorul; grid 2×2:
`Team/team-grid.png`. Detalii în `Team/README.md`.

## Notă

Screenshot-urile sunt capturi reale de pe **Samsung S24 Ultra** (aplicația
Flutter) și din **Waterfox** (control room). Nu sunt mock-up-uri.
