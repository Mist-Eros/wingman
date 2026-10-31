# Wingman — screenshots for the PPTX

Folder pregătit pentru **RaresCut → Claude → PowerPoint**. Toate capturile sunt reale
(Samsung S24 Ultra + Waterfox), nu mock-up-uri. Sunt luate din build-ul curent:
meniu **4 rânduri × 2 coloane**, dashboard light în stil admin, fără logo în UI,
istoric cu clear-all.

- Repo: `Mist-Eros/wingman` · folder: `docs/screenshots/`
- Telefon: **1080 × 2340** (portret)
- Dashboard: **1230 × 880** (landscape)
- Carduri echipă: **1600 × 1450** (portret)

## Ce să-i ceri lui Claude

> „Fă un deck PPTX de 10–12 slide-uri, 16:9, în engleză, pentru un hackathon de
> aviație. Folosește imaginile din acest folder fără să le deformezi; păstrează
> capturile de telefon pe verticală, pe fundal închis, și pune-le pe coloane.”
> Atașează folderul + acest README + `manifest.json`.

## Ordinea sugerată a slide-urilor

| # | Slide | Imagini |
|---|---|---|
| 1 | Title — Wingman | `00_app_icon.png` |
| 2 | Problem — incident reporting at a busy airport | — |
| 3 | Solution — 3 taps, local AI, dispatcher + crew | `03_menu_categories_4x2.png` |
| 4 | Reporter — speak or use the menu | `02_reporter_voice.png`, `06_reporter_verification.png` |
| 5 | The 8×8×8 catalog — 512 problems, 3 levels | `03`, `04`, `05` |
| 6 | Dispatcher admin — live queue | `07_dispatcher_queue.png`, `09_dispatcher_low_priority.png` |
| 7 | History — resolved/denied + clear all | `08_dispatcher_history.png` |
| 8 | Crew — join and vote (one per department) | `10_crew_queue.png`, `11_crew_joined.png` |
| 9 | Notifications — only the involved departments | `12_notification_shade.png` |
| 10 | Desktop control room — same admin view | `13_dashboard_queue.png`, `14_dashboard_history.png`, `15_dashboard_report_modal.png` |
| 11 | Accessibility & safety | `17_accessibility.png`, `19_photo_prompt.png` |
| 12 | Live GPS map on real OpenStreetMap tiles | `18_live_gps.png` |
| 13 | Rewards / account | `20_account_points.png` |
| 14 | Ticket media — persistent photo + map toggle | `21_ticket_media_photo.png`, `22_ticket_media_map.png` |
| 15 | Operability — local AI, TLS pinned, DevTools | `16_devtools.png` |
| 16 | Team — who built what | `team/team-grid.png` (sau cele 4 carduri) |

## Conținut

| Fișier | Ce arată |
|---|---|
| `00_app_icon.png` | iconița aplicației (logo-ul rămâne doar aici) |
| `01_login.png` | login, 5 conturi demo, sky adaptiv |
| `02_reporter_voice.png` | reporter: ține microfonul apăsat |
| `03_menu_categories_4x2.png` | meniu nivel 1: 8 categorii, 4×2 |
| `04_menu_subcategories_4x2.png` | meniu nivel 2: 8 subcategorii |
| `05_menu_problems_4x2.png` | meniu nivel 3: 8 probleme, cod operațional |
| `06_reporter_verification.png` | ce a înțeles AI-ul + probabilitate Craiova |
| `07_dispatcher_queue.png` | admin view: Coadă + Istoric, bară de raportare |
| `08_dispatcher_history.png` | istoric + „Golește istoricul” |
| `09_dispatcher_low_priority.png` | card low-priority alb, quorum 0/1 |
| `10_crew_queue.png` | echipaj filtrat pe departament |
| `11_crew_joined.png` | Preia → tichet în lucru |
| `12_notification_shade.png` | notificare locală, doar departamentele implicate |
| `13_dashboard_queue.png` | Waterfox: coadă live, temă light admin |
| `14_dashboard_history.png` | Waterfox: Istoric |
| `15_dashboard_report_modal.png` | Waterfox: formular raportare |
| `16_devtools.png` | DevTools: AI/STT/WSS/quorum |\n| `17_accessibility.png` | Accessibility profiles (blind/mute/deaf/colorblind/motor/cognitive) |\n| `18_live_gps.png` | Live GPS map on OpenStreetMap tiles, marker + accuracy + coordinates |\n| `19_photo_prompt.png` | Optional 5-second photo prompt |\n| `20_account_points.png` | Employee account: points + attended incidents |
| `21_ticket_media_photo.png` | Dispatcher detail with attached photo (toggle Foto) |
| `22_ticket_media_map.png` | Same ticket, toggled to Hartă |
| `23_dashboard_statistics.png` | Desktop admin statistics |
| `24_phone_statistics.png` | Phone admin statistics |
| `team/*.png` | carduri egale + grid 2×2 |

## Note pentru slide design

- Capturile de telefon au mult spațiu; puneți-le pe fundal navy (`#081120`),
  cu colțuri rotunjite, fără stretch.
- Dashboard-ul e landscape; lăsați-l să ocupe 60–70% din slide.
- Accent: `#5BA7FF`; text: `#E8F0FA` pe închis, `#0F172A` pe light.
- Nu adăugați logo peste capturi — logo-ul există doar ca iconiță.
- Numere pentru slide-ul de tehnologie: **512** incidente în meniu, **14** coduri
  operaționale, **103/103** smoke, **161** teste, **59** ocurențe oficiale în catalog,
  quorum **1** (low/medium) / **2** (high/critical).

