# How the team worked — timeline

All four people worked on **2026-10-30**. The Lead froze the contract layer and backend first, then
the three feature branches were built in parallel against it and merged in one integration pass.
Times are commit times from the git history.

> Visual version (rendered PNG): `D:\Hackathon\Screenshots\Team\timeline.png`
> Per-person cards: `D:\Hackathon\Screenshots\Team\lead.png`, `friend1-reporter.png`,
> `friend2-dispatcher.png`, `friend3-crew.png`.

## Timeline

| Time | Who | What landed |
|---|---|---|
| 16:15–17:18 | **Lead** | Repo, taxonomy, wire contracts, FastAPI + WSS + TLS, `/api/analyze` conversational contract, first 50 tests. |
| 19:21 | **Friend 3** (crew) | `feat(crew): replace stub with Preia/Rezolvat phone UI` (`0440163`). |
| 19:30 | **Friend 2** (dispatcher) | Windows/live dispatcher dashboard with urgency-colored demo tickets (`60051a3`). |
| 19:38 | **Friend 1** (reporter) | Hold-to-talk voice flow, smart follow-ups, urgency from what was said (`5b7e2c9`). |
| 19:44–19:55 | **Friend 3** | Chrome preview harness + widget tests (`5de1d6a`), airport-ops phone UI polish (`5fee0df`). |
| 19:59 | **Friend 2** | Dispatcher UX polish: demo/live controls, shortcuts, zones, timeline (`f563740`). |
| 20:09–20:19 | **Lead** | Merged all three features (`c1e3d7e`, `1625b79`, `6544404`, `d499b35`); server mirrors reporter urgency; 141 tests. |
| 21:01 | **Lead** | Design system: navy airport-ops theme, semantic urgency palette, design tokens. |
| 21:08–21:14 | **Lead** | Dispatcher live-by-default + compact phone header + SafeArea; session persistence; TEAM.md + 3-min demo script. |
| 21:28 | **Lead** | Demo accounts (hashed passwords), department-scoped alerts, aerospace login, back-button routing, web control room. |
| 21:51–22:05 | **Lead** | Six time-of-day skies, DevTools, Waterfox control room, scoped Android notifications, S24 fit. |
| 22:32 | **Lead** | Firefighter + Guard roles, reporter account removed, AI takes all available info on both client and server. |
| 22:43–22:59 | **Lead** | Dispatch-first AI policy; Craiova airport zone catalog (entrances/exits, terminals, security, customs, parking, apron, runway…). |
| 23:13 | **Lead** | Repo cleanup + formatting (dart format, black), README/layout/docs indexes, single-field PC report dialog. |

## By person

### Lead — @Mist-Eros
**Owns:** `lib/core/**`, `lib/main.dart`, `backend/**`, `scripts/**`, `docs/**`, design system, demo hardening.
**Built:** closed 14-type taxonomy; one-listener TLS backend (REST + WSS, in-memory store, 5 s override,
vote quorum); local Qwen2.5 classification + deterministic guards; faster-whisper STT; pinned CA;
navy airport-ops theme with six time-of-day skies and DevTools; five hashed demo accounts with
department-scoped notifications; Waterfox control room and report form; APK pipeline; verification
gates (analyze, 160 tests, smoke 90/90, ALL GATES PASSED).
**Showcase:** `Team/lead.png`.

### Friend 1 — rarescu08 — Reporter
**Owns:** `lib/features/reporter/**`.
**Built:** push-to-talk voice reporter (record → local Whisper → transcript), a local conversation
brain that asks only what is missing (max 3 questions), urgency inference from what was said,
confirmation card with editable words, typed and 14-button-menu fallbacks. Later extended by the
Lead's dispatch-first policy (no "is anyone in danger?" question).
**Commit:** `5b7e2c9` · merged `1625b79`.
**Showcase:** `Team/friend1-reporter.png`.

### Friend 2 — Radu Fita — Dispatcher
**Owns:** `lib/features/dispatcher/**`.
**Built:** dispatcher dashboard with live/demo modes, urgency counters, department distribution,
per-ticket timeline, zones, filters, history, density control, and the 5-second override card
(Confirmă / Respinge / Reclasifică) with keyboard shortcuts; Windows runner additions.
**Commits:** `60051a3`, `f563740` · merged `c1e3d7e`.
**Showcase:** `Team/friend2-dispatcher.png`.

### Friend 3 — crew — name/handle to confirm
**Owns:** `lib/features/crew/**`.
**Built:** crew queue scoped by department, **Preia** (join) and **Rezolvat** (vote) with quorum
progress, live resolution SnackBar, WSS banner, airport-ops card design, and widget tests.
(Their feature commits were authored under the shared demo-machine git identity; the files under
`lib/features/crew/**` are theirs.)
**Commits:** `0440163`, `5de1d6a`, `5fee0df`.
**Showcase:** `Team/friend3-crew.png`.

## Final state

| Gate | Result |
|---|---|
| `flutter analyze` | No issues |
| App tests | 160 passed |
| Backend smoke (strict TLS) | 90/90 |
| `scripts/verify_all.ps1 -Live` | ALL GATES PASSED |
| Demo APKs | rebuilt + installed on the S24 Ultra |
