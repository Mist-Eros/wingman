# 48-hour plan — hard demo-ready gate at H36

**H0 = kickoff.** The clock column assumes H0 = **Friday 18:00**; if the team starts at another
hour, shift the clock column, never the hour numbers — **the gate is H36 regardless**, and the
demo is at H48.

Working agreement: hour numbers win over "just one more fix". If something is not on this
table, it is not happening.

Legend: **L** = Lead (you) · **F1** reporter · **F2** dispatcher · **F3** crew.

---

## Phase 0 — Contracts + infrastructure (H0 → H4)

| Hour | Clock | Owner | Deliverable | Gate |
|---|---|---|---|---|
| H0–H1 | Fri 18–19 | L | Install toolchain on the laptop (git, Python 3.12, OpenSSL, Flutter/Android SDK, Ollama + model). `git init`, push this skeleton to the shared repo, tag `contracts-v1`. | Repo pushed; teammates can clone |
| H0–H1 | Fri 18–19 | F1–F3 | Clone, `flutter pub get`, app boots to the role picker on their machine. Read `CONTRACTS.md` §1–§6. | 3 × "app boots" in chat |
| H1–H2 | Fri 19–20 | L | `.\scripts\gen_certs.ps1 -Force`; `backend\run.ps1`; `python backend\seed_demo.py`; `python scripts\smoke_test.py` (37/37); commit `assets/certs/ca.crt`. | Smoke test green, one phone shows live tickets |
| H2–H3 | Fri 20–21 | L | **iOS reality check**: does anyone have a Mac? If not, freeze the demo on Android and say so now (see `demo-risks.md` R4). | Written decision in chat |
| H3–H4 | Fri 21–22 | L | Phone onboarding: CA profile + app on 1 iPhone + 1 Android; `docs/certs-and-phones.md` sign-off table filled for device #1 of each OS. | 2 devices connect (WSS banner green) |
| H3–H4 | Fri 21–22 | F1–F3 | Feature skeleton: screen scaffold, navigation to core, first real widget (no mock data). | Each folder compiles |

**Milestone M1 (H4):** one physical phone, one real ticket, end-to-end. If this is not true,
everything else stops until it is.

---

## Phase 1 — Feature v1 (H4 → H12)

| Hour | Clock | Owner | Deliverable |
|---|---|---|---|
| H4–H9 | Fri 22–Sat 03 | F1 | Reporter: big button, STT capture, 14-type menu grouped by category, POST `/api/reports`, pending/error states |
| H4–H9 | Fri 22–Sat 03 | F2 | Dispatcher: live list, urgency/confidence chips, confirm/deny, 5 s countdown card with reclassify sheet |
| H4–H9 | Fri 22–Sat 03 | F3 | Crew: dispatch list, join, vote, quorum bar, resolved state |
| H4–H9 | Fri 22–Sat 03 | L | Ollama prompt tuning against `/api/analyze` with 20 golden transcripts; keep `ai.py` fallback in sync; fix integration bugs for teammates |
| H8–H10 | Sat 02–04 | F1–F3 | **Sleep block** (staggered: at most one of F1–F3 awake at a time) |
| H10–H12 | Sat 04–06 | L | **Integration window 1**: merge `feat/*` → `main`; `flutter analyze`; smoke test; run all three stubs-replaced screens on one device |

**Milestone M2 (H12):** `main` is demo-able on 2 devices (reporter → dispatcher).
Anyone can clone `main` and see the flow. If a feature is not mergeable, it stays on its
branch — `main` is never broken.

---

## Phase 2 — Feature v2 + real AI (H12 → H24)

| Hour | Clock | Owner | Deliverable |
|---|---|---|---|
| H12–H18 | Sat 06–12 | F1 | Voice polish: recording UI, transcript confirm, retry, keep text input fallback |
| H12–H18 | Sat 06–12 | F2 | Override UX: 5 s ring/countdown, confirm/deny/reclassify, auto-dispatch feedback, department filter chips |
| H12–H18 | Sat 06–12 | F3 | Notification-style dispatch, join/leave, vote feedback, resolved banner |
| H12–H18 | Sat 06–12 | L | AI quality: 20-scenario golden set, prompt iteration, verify codes/urgency/departments, tune `CONFIDENCE_THRESHOLD`; keep latency < 8 s warm |
| H18–H20 | Sat 12–14 | All | **Integration window 2** + first full 4-device run; fix cross-feature bugs |
| H20–H22 | Sat 14–16 | L | Second smoke test round + `gen_certs` sanity on all 4 devices; commit `optional` secure-storage upgrade if green |
| H22–H24 | Sat 16–18 | L | **Contract freeze**: `lib/core`, `main.dart`, `backend/**`, taxonomy/JSON frozen. Only Lead bug fixes allowed. Announce it. |

**Milestone M3 (H24):** full flow works once on 4 devices, WSS live, AI in the loop. From here
only hardening, no new product surface.

---

## Phase 3 — Hardening + checkpoint sprint (H24 → H36)

| Hour | Clock | Owner | Deliverable |
|---|---|---|---|
| H24–H27 | Sat 18–21 | L | Rotation sleep #1 (3 h). F1–F3: bug list only, no new UI |
| H24–H27 | Sat 18–21 | F1–F3 | Demo-path bugs, empty/error/offline states, 30-second cold-start test each |
| H27–H30 | Sat 21–24 | L | Rotation sleep #2 for F1–F3 (staggered). L: stability, logs, seed data, fallback build |
| H27–H30 | Sat 21–24 | L | Pre-build the **emergency HTTP build** (`--dart-define=DEV_INSECURE=true --dart-define=API_BASE=http://IP:8080`) and install it on all 4 phones alongside the TLS build |
| H30–H32 | Sun 00–02 | All | **Integration window 3**: final merges, `flutter analyze`, smoke test, taxonomy check |
| H32–H36 | Sun 02–06 | All | **Demo-run sprint**: script the 6-minute demo, 3 consecutive clean runs on 4 charged devices, record a full video backup, time it |

### 🚦 HARD GATE M4 — H36 (Sun 06:00): DEMO-READY

Do not proceed unless **all** are true:

- [ ] Fresh loop: start laptop → `backend\run.ps1` → `seed_demo.py` → 4 phones connect in < 10 min.
- [ ] Six-minute demo completed **3× in a row** without a crash, dev console error or manual DB poke.
- [ ] `flutter analyze` clean · `python scripts\smoke_test.py` = 37/37 · `sync_taxonomy.py` OK.
- [ ] Backup video of the full flow recorded and playable.
- [ ] Emergency HTTP build installed on all phones (not just available on the laptop).
- [ ] Laptop hotspot fallback exercised once on real phones.
- [ ] Devices charged, chargers packed, demo data seeded, `git tag demo-ready` pushed.

If any box is unchecked at H36: **cut scope** (drop voice → menu-only, drop one crew phone,
drop animations) rather than extend the deadline. The API and screens are independent; the
demo can lose one beat and still tell the story.

---

## Phase 4 — Rehearsal, rest, presentation (H36 → H48)

| Hour | Clock | Owner | Deliverable |
|---|---|---|---|
| H36–H40 | Sun 06–10 | All | **Sleep.** Explicitly scheduled; tired people break demos. |
| H40–H42 | Sun 10–12 | L | Production polish: app icon/name, splash, README screenshots, architecture diagram for the slide; freeze code |
| H42–H44 | Sun 12–14 | All | Two timed rehearsals + judge Q&A drill (`demo-risks.md` §6); fix only blockers |
| H44–H45 | Sun 14–15 | L | Final device state: airplane mode off, Wi-Fi auto-join on, brightness 100%, notifications off, screenshots saved, video on the laptop |
| H45–H47 | Sun 15–17 | All | Buffer / rest / demo setup at the venue |
| H47–H48 | Sun 17–18 | All | **Demo.** No code changes after H44. |

---

## Hourly discipline (what keeps 4 people mergeable)

1. **Push every 2 h**, even if incomplete: `git pull --rebase origin main; git push`. A branch
   that lives 8 h unpushed is a merge conflict factory.
2. **Integration windows are the only times `main` changes** (H10–H12, H18–H20, H30–H32).
   Between windows the Lead fixes, does not merge features.
3. **Blocked > 20 min → ask.** A message costs 2 minutes; a wrong assumption costs an hour.
4. **Demo path first.** Any work that is not visible in the 6-minute script goes last.
5. **No contract edits after H24.** If it's not in `CONTRACTS.md`, it doesn't exist.

## Contingency ladder (if you are behind)

| If at | and this is missing | do this |
|---|---|---|
| H12 | one feature still stub | ship `main` with 2 roles; the third merges at H24 |
| H20 | AI quality poor | freeze prompt at current best, lower demo reliance on AI (menu flow is deterministic) |
| H24 | 4 devices not working | officially demo on 2 devices + video of the other 2 |
| H32 | flutter analyze red | revert to last green commit, cherry-pick demo fixes only |
| H36 | gate not met | cut scope (menu-only reporter, 2 crew phones), not the timeline |
