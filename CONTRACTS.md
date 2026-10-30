# CONTRACTS — frozen interfaces and the merge protocol

**Read this before writing code.** Everything here is already implemented and tested in this
repo. The three feature folders build against it; the Lead owns it. If something here blocks
you, ask for a contract change (section 9) — do **not** edit `lib/core/`, `lib/main.dart` or
`backend/` yourself.

---

## 1. The five rules

1. **Never edit** `lib/core/**`, `lib/main.dart`, `backend/**`, `scripts/**`, `tool/**`.
   Those are Lead-owned; two people touching `Taxonomy` or `main.dart` inside a 48 h window is
   how demos die.
2. **Import from core, never copy it.** No local `Ticket` model, no local enum, no local API
   client in a feature folder.
3. **The wire is immutable.** Never rename a `wire` value, a JSON key, a status, an event
   type, or a screen class name. Adding is a contract change (section 9).
4. **Run the gates** before you ask for a merge (section 8).
5. **Your feature must not crash the app.** A screen that throws unmounts the whole demo.
   Catch errors, show `board.lastActionError`, and keep the rest of the app alive.

---

## 2. Ownership

| Area | Owner | You may read | You may write |
|---|---|---|---|
| `lib/core/**`, `lib/main.dart` | Lead | always | never |
| `backend/**`, `scripts/**`, `tools/**`, `docs/**` | Lead | always | never |
| `lib/features/reporter/**` | Friend 1 | always | always |
| `lib/features/dispatcher/**` | Friend 2 | always | always |
| `lib/features/crew/**` | Friend 3 | always | always |

---

## 3. Screen contract (what `main.dart` mounts)

`main.dart` is frozen. It imports exactly three classes and gives them **zero constructor
arguments**:

```dart
import 'features/reporter/reporter_screen.dart';    // class ReporterScreen
import 'features/dispatcher/dispatcher_screen.dart';// class DispatcherScreen
import 'features/crew/crew_screen.dart';            // class CrewScreen
```

Keep the file names, class names, and `const ReporterScreen({super.key})` style constructors.
The current files are **replaceable stubs** that already render live ticket counts.

Routes (do not add routes without asking):
`/` role picker · `/reporter` · `/dispatcher` · `/crew`.

---

## 4. `CoreScope` — how features get dependencies

```dart
import '../../core/core_scope.dart';

final session = CoreScope.sessionOf(context); // Session(role, userId, displayName)
final board   = CoreScope.boardOf(context);   // TicketBoard extends ChangeNotifier
final api     = CoreScope.apiOf(context);     // ApiClient (REST + WSS)
CoreScope.of(context).onSignOut();            // back to the role picker
```

* `session.userId` is what you pass as `crew_id`; `session.displayName` is the label.
* Never construct `ApiClient`, `TicketBoard` or `TokenStore` in a feature.
* `board` is already started once at app boot and holds a single WSS connection.

### `TicketBoard` API (read-only cache + actions)

| Member | Meaning |
|---|---|
| `tickets` | sorted list: pending override → urgency → newest |
| `pendingOverrides` | tickets in the 5 s window (dispatcher screen top section) |
| `activeTickets` | dispatched + in_progress |
| `forDepartment(Department.security)` | tickets whose primary or standby includes it |
| `find(id)` | one ticket or null |
| `connected` / `loading` / `lastError` / `lastActionError` | banner state |
| `refresh()` | pull-to-refresh |
| `confirm(id)`, `deny(id, reason:)`, `reclassify(id, incidentCode:)`, `join(id, crewId:)`, `vote(id, crewId:)` | call API, update cache, return `bool`; on `false` read `lastActionError` |

Always render inside `ListenableBuilder(listenable: board, builder: ...)`.

---

## 5. `Ticket` field contract (JSON is snake_case)

`lib/core/models/ticket.dart` ↔ `backend/app/store.py` — verified by
`scripts/smoke_test.py` (exact key-set comparison) and `scripts/check_wire_parity.py`.

| JSON key | Type | Notes |
|---|---|---|
| `id` | string | UUID |
| `incident_code` | string | one of the 14 codes |
| `label_ro` | string | snapshot of the Romanian label |
| `category` | string | `safety_fire` · `security` · `maintenance` · `operations` |
| `urgency` | string | `low` · `medium` · `high` · `critical` |
| `status` | string | see lifecycle |
| `source` | string | `voice` · `menu` |
| `reporter_id`, `reporter_name` | string | who reported |
| `transcript` | string | STT text or menu label |
| `location` | object | `{terminal, zone, lat, lng, note}` |
| `confidence` | number 0–1 | below `0.65` ⇒ override window |
| `ai_source` | string | `ollama` · `fallback` · `manual` |
| `ai_rationale` | string \| null | ≤ 200 chars, Romanian |
| `primary_departments` | string[] | from the taxonomy |
| `standby_departments` | string[] | from the taxonomy |
| `joined_crew_ids` | string[] | crew ids |
| `resolve_votes` | int | approving votes |
| `resolve_voter_ids` | string[] | who approved (prevents double counting) |
| `quorum` | int | approvals needed (default 2) |
| `override_deadline` | ISO date \| null | only while `pending_override` |
| `dispatched_at`, `resolved_at` | ISO date \| null | |
| `resolution_note` | string \| null | dispatcher denial reason / vote summary |
| `decided_by` | string \| null | dispatcher id, `null` = auto-dispatch |
| `created_at`, `updated_at` | ISO date | UTC, `...Z` |
| `version` | int | server revision; `TicketBoard` ignores older versions |

Dart helpers you can use directly: `isPendingOverride`, `remainingOverrideSeconds()`,
`confidenceLabel` (`"87%"`), `isJoinedBy(crewId)`, `hasVotedBy(crewId)`, `ageSeconds()`,
`departmentsLabel`, `location.display`, `status.labelRo`, `urgency.labelRo`,
`category.labelRo`, `source.labelRo`, `aiSource.labelRo`.

### Lifecycle

```
POST /api/reports
   ├── confidence ≥ 0.65 ──────────────────────────────► dispatched
   └── confidence < 0.65 ──► pending_override ──┬──────► dispatched   (confirm)
                              │ 5 s deadline     ├──────► denied       (deny)
                              │                  └──────► dispatched   (override code)
                              └── timer expires ────────► dispatched   (auto, decided_by: null)

dispatched ──first crew joins──► in_progress ──quorum approve votes──► resolved
any open ticket ──dispatcher deny──► denied
```

Who may transition what: **dispatcher** confirm/deny/override any open ticket; **crew** join
only `dispatched`/`in_progress` and vote only after joining; **server** flips to `resolved`.

---

## 6. REST contract

Base URL: `https://<laptop>:8443`. All `/api/*` need `Authorization: Bearer <API_TOKEN>`.
Every mutation returns `{"ticket": {...}}`; `POST /api/reports` returns **201**.
Errors are `{"detail": "human readable"}` with status `400` (bad input/code), `401`
(token), `404` (ticket id), `409` (illegal transition).

### POST `/api/reports` — mirrors Dart `ReportDraft.toJson()`

```json
{
  "source": "voice",
  "transcript": "Este fum lângă poarta 12...",
  "reporter_id": "reporter-42",
  "reporter_name": "Andrei P.",
  "location": {"terminal": "T1", "zone": "Poarta 12", "lat": null, "lng": null, "note": null},
  "hint_code": null,
  "use_ai": true
}
```

* Voice flow: `source: "voice"`, `transcript` = STT text, `use_ai: true`.
* Menu flow: `source: "menu"`, `hintCode` = the tapped code, `use_ai: false` (instant, no AI
  latency) or `true` if you want AI verification.
* `hint_code` not in the taxonomy ⇒ `400`.
* The response may take **20–30 s on a cold model** — disable the button, show a spinner,
  never fire two reports from one tap.

Other bodies (all optional fields are nullable):

| Endpoint | Body |
|---|---|
| `.../confirm` | `{"dispatcher_id": "dispatcher-1", "dispatcher_name": "Dana"}` |
| `.../deny` | `{"reason": "fals pozitiv", "dispatcher_id": "dispatcher-1"}` |
| `.../override` | `{"incident_code": "SF-FIRE", "urgency": "critical", "reason": "..."}` |
| `.../join` | `{"crew_id": "crew-7", "crew_name": "Echipaj 7"}` |
| `.../vote` | `{"crew_id": "crew-7", "approve": true}` |

`POST /api/analyze` (debug/prompt tuning) takes `{transcript, location, hint_code}` and returns
`{"classification": {...}}` — it does not create a ticket.

---

## 7. WSS contract

`wss://<laptop>:8443/ws?token=<API_TOKEN>` (header auth also accepted). The client is
`ApiClient.connectEvents()`; you never open a socket yourself.

Envelope:

```json
{"type": "ticket.updated", "ts": "2026-10-30T15:40:12.111Z", "data": {"ticket": {...}}}
```

| `type` | when | `data` |
|---|---|---|
| `hello` | on connect | `{server, taxonomy_version, incident_types, override_window_seconds}` |
| `ticket.created` | after `POST /api/reports` | `{ticket}` |
| `ticket.updated` | confirm/deny/override/join/vote/auto-dispatch | `{ticket, action, ...}` |
| `ticket.resolved` | quorum reached | `{ticket, action: "voted"}` |
| `store.reset` | dev reset | `{removed}` |
| `ping` | every 20 s | `{}` |

`TicketBoard` turns these into `Ticket` objects; screens only need `ListenableBuilder`. Server
args (`action`, `crew_id`, ...) are available on `ServerEvent.data` if you need them, but do
not depend on them for rendering.

Synthetic connection events (client-side): `ApiClient` emits
`ServerEvent.typeConnected` / `typeDisconnected` with `connected: true/false` — `board.connected`
already reflects them, use that for the "reconectare..." banner.

---

## 8. Taxonomy contract

* The **closed list** is `IncidentTaxonomy.all` (14 types, 4 categories). `IncidentTaxonomy.codes`
  is the only legal set; `IncidentTaxonomy.byCode(code)` for lookups; `byCategory(...)` for menus.
* `OP-OTHER` is the mandatory catch-all — never let a report fail because it doesn't match.
* Urgency order: `Urgency.level` 1..4; the server may **raise** but never lower a type's default.
* Departments: `Department.*` enum only — no raw strings in UI.
* Change flow: Lead edits `lib/core/incidents/taxonomy.dart`, then
  `dart run tool/emit_taxonomy.dart --write` (or `python scripts/sync_taxonomy.py --write`),
  then everyone pulls. `scripts/sync_taxonomy.py` fails the build on drift.

Example menu section (Friend 1):

```dart
for (final category in IncidentCategory.values)
  for (final type in IncidentTaxonomy.byCategory(category))
    ListTile(title: Text(type.labelRo), subtitle: Text(type.code), onTap: () => ...);
```

---

## 9. Changing a contract (rare, Lead-approved)

Send the Lead exactly:

1. **What** (`Ticket` field / endpoint / event / screen signature).
2. **Why** (which user story breaks without it).
3. **Who else is affected** (reporter/dispatcher/crew/backend).
4. **Deadline** (hour of the timeline).

The Lead updates `lib/core`, backend and the doc in one commit, bumps nothing unless a `wire`
value changes, and announces in the team channel. Never "just add it" locally.

---

## 10. Git / merge protocol

* Branches: `feat/reporter`, `feat/dispatcher`, `feat/crew` (one per teammate), `main` is
  Lead-owned and always demo-able.
* Work on your branch only; `git pull --rebase origin main` before each push.
* **Integration windows** (see `docs/48h-timeline.md`): H10–H12, H20–H24, H30–H32, then H36
  freeze. Outside those windows `main` is not merged.
* Conflicts are only possible in **your own** feature folder or in `pubspec.yaml` — if you see
  a conflict in `lib/core` or `main.dart`, stop and ping the Lead; do not resolve it yourself.
* Merge gates for every PR:
  1. `flutter analyze` clean (no new warnings).
  2. App still builds and boots to the role picker.
  3. `python scripts/smoke_test.py` 37/37 (backend untouched by you, but proves the merge
     environment).
  4. Your flow demonstrated on **one real device**, not only the emulator.
* Commit message: `reporter: voice capture + STT fallback (H14)` — area first, then what.
* After H36 (**demo freeze**): only bug fixes that are reachable from the 6-minute demo path,
  one-line PRs, reviewed by the Lead. New features go behind `--dart-define` flags or not at
  all.

---

## 11. Definition of done (per feature)

- [ ] Screen keeps the frozen class name and builds with `const X({super.key})`.
- [ ] Uses `CoreScope` only; no local models/clients; no edits outside your folder.
- [ ] Loading, empty, error, and offline (`board.connected == false`) states render.
- [ ] Every async button is disabled while in flight and shows a spinner; failures surface
      `board.lastActionError` in a `SnackBar`.
- [ ] No unhandled exceptions in `flutter run` console during the happy path.
- [ ] Works after a cold app start (no hot reload) on a physical phone.
- [ ] 30-second manual test: report → see it appear on the dispatcher screen → act on it.
