# Prompt for Claude — Wingman animated pitch deck

> Copy everything between the rules into Claude. Attach/upload the `docs/screenshots`
> folder if Claude cannot read local files. If Claude can run code in the repo,
> point it at `D:\Hackathon\Wingman`.

---

You are a senior product designer and creative presentation developer. Build a
**real, editable, animated PowerPoint deck (.pptx)** for a hackathon demo called
**Wingman**. The deck must feel like a polished product launch from an airport
operations company — calm, confident, precise, premium. Not a generic hackathon
template, not a slide full of bullet points, and definitely not clip-art.

## Project context

Wingman is an airport incident response demo. An airport employee reports an
incident by voice or by a deterministic 8×8×8 menu (512 combinations). Local
speech-to-text turns voice into text, a local Ollama model classifies it into a
closed 16-type taxonomy, and the ticket is dispatched instantly over WebSocket
to a control room and the correct crew phones. Crews join, vote and resolve
through a department-aware quorum. Everything runs locally: Flutter app,
FastAPI backend, SQLite persistence, local AI, TLS with a pinned local CA.

The audience is hackathon judges — mixed technical and non-technical. The spoken
pitch is **3 minutes**, followed by Q&A. The deck should be **10–12 slides**,
16:9, in **Romanian** with common English technical terms kept as-is.

## Non-negotiable facts (do not invent numbers or features)

- Voice or **8×8×8 menu = 512 combinations**, 3 taps per level.
- Closed taxonomy: **16 incident types**; AI output is validated against it.
- Local AI: **Ollama** for classification, **faster-whisper** for STT, no cloud.
- Deterministic fallback + keyword guards if the model is unavailable/uncertain.
- If Whisper is unusable on the initial report: **one** repeat only, then the
  app opens the deterministic 8×8×8 menu.
- Department-aware dispatch: dynamic quorum, **one responder per primary
  department**; standby teams are not woken for nothing.
- Duplicate reports merge into one ticket: report count increments, distinct
  reporters are shown with a 👥 counter.
- Rewards: **2 points** for reporting, **5 points** for joining + resolving.
  Self-report → self-resolve alone on a **low/medium** incident earns **0**
  (anti-farming). High/critical incidents still count.
- Statistics: what problems happen and how often, by **day / week / month / year**.
- Persistence: tickets, photos, votes and history survive backend restarts in
  **SQLite** (`backend/data/wingman.db`).
- Location gate: location must be on and the phone within **2 km** of the
  airport; GPS off and known out-of-range are hard locks. If the phone has no
  GPS fix indoors, the user gets an explicit “continue without verification”.
- Tested quality: **190 Flutter tests**, **22 backend tests**, **108/108 live
  smoke checks**, `flutter analyze` clean.
- Live on multiple phones + desktop control room via **WSS**.

## Deliverable

Produce:

1. `Wingman_Pitch.pptx` — 16:9, editable, with **native PowerPoint animations
   and transitions** (not just a video, not an HTML deck, not a sequence of
   static frames pretending to be animated).
2. `Wingman_Pitch.pdf` — static preview for review.
3. The reproducible build script (Python/Node) and any generated assets.
4. Optional thumbnails of 3–4 key slides for a quick sanity check.

If you can run code, output the files into the repo’s `dist/` folder (or a
reasonable equivalent) and tell me the exact paths. If you cannot produce a
real `.pptx` with animations, say so clearly before starting and propose the
closest reliable alternative.

## Creative direction

**Product metaphor:** a runway at blue hour / airport operations control room,
not a startup SaaS gradient. Navy, sky, precise lines, amber signal lights.
Quiet confidence. No neon cyberpunk, no robot brains, no stock people, no
generic “AI sparkle” icons.

**Palette**

- Midnight navy: `#081A2B`
- Deep ops navy: `#0F2740`
- Wingman blue: `#1D4E89`
- Signal cyan: `#4FC3F7`
- Runway amber: `#F6C453`
- Alert red: `#D64545`
- Paper: `#F8FAFC`
- Slate text: `#94A3B8`

**Typography**

- Use fonts that are available on a normal Windows machine:
  **Segoe UI Semibold / Segoe UI** or **Aptos Display / Aptos**.
- Titles: 30–42 pt, tight tracking, sentence case.
- Body: 18–22 pt minimum. Do not put paragraphs on slides; put the detail in
  speaker notes.
- One strong sentence per slide, not five bullets.

**Visual system**

- 16:9, 13.333 × 7.5 in.
- Generous negative space; left-aligned text; a thin 1 px “runway line” motif.
- Screenshots in device-like rounded frames with subtle shadows; crop out
  browser chrome/status bars where possible.
- Use geometric shapes and simple line icons (plane, radio tower, shield,
  people, waveform, database, map pin) drawn natively in PowerPoint.
- No external stock photos. No logos you do not own. No emoji as main imagery.
- Keep readable contrast; never place body text over a busy screenshot.

## Motion design

Animations must communicate sequence, not decorate. Use **native PowerPoint
entrance animations and slide transitions**. Prefer Fade, Wipe, Fly In and
Grow & Turn with short durations (0.25–0.5 s), staggered by 0.08–0.15 s.
Avoid spins, bounce loops, confetti and things that feel childish.

- **Cover:** runway line draws across; plane icon glides in; title fades up;
  tagline appears last.
- **Problem:** fragmented radio/message cards slide in from both sides and pile
  up; one central “single source of truth” line then cuts through them.
- **Idea:** one sentence morphs/wipes into a structured ticket card: type,
  urgency, location, teams. Use a wipe or appear sequence if true morph is not
  reliably available.
- **Live demo:** phone/dashboard screenshots enter from the right with a subtle
  scale; a highlight ring lands on the AI code, then on the required team;
  step labels appear in order: “vorbeste → intelege → trimite → rezolva”.
- **AI that knows its limits:** pipeline nodes appear one by one
  (voice → text → closed taxonomy → dispatch); a confidence bar fills; a small
  “repeat once” chip pulses once; the 8×8×8 menu fades in as fallback.
- **Dispatch:** primary department cards appear; standby cards stay dim; one
  check mark per primary department; quorum indicator reaches completion.
- **Statistics:** bars grow from baseline; numbers appear with the bars. Do not
  fake count-up text by creating dozens of hidden slides.
- **Architecture:** nodes fade in; connector lines wipe in one direction;
  SQLite disk and WSS arrows appear last.
- **Close:** logo settles; tagline fades; no confetti.

**Transitions:** one consistent family (Fade or subtle Push) at 0.35–0.5 s.
Do not auto-advance the whole deck; presenter controls the click sequence.
Every animation must still look good as a static slide after it finishes.

## Slide-by-slide storyboard

### 1. Cover
- Layout: dark navy background; thin cyan runway line; plane silhouette.
- Text: **WINGMAN** / “Airport incident response, without the radio chaos.” /
  “One report. The right people. Live.”
- Small line: “Flutter · FastAPI · local AI · SQLite · WSS”.
- Animation: runway line draw → plane glide → title → tagline.
- Speaker note: introduce the demo in one sentence; do not read the slide.

### 2. The problem
- Visual: three or four fragments — radio call, phone call, chat message,
  handwritten note — converging into a noisy knot.
- Headline: “Un incident. Patru canale. Nimeni nu vede același lucru.”
- Small source line: “Radio congestion · missing context · no shared truth”.
- Animation: fragments stagger in and collide; headline appears last.
- Speaker note: explain the cost of coordination, not the technology.

### 3. The shift
- Headline: “Raportul devine dispeceratul.”
- Visual: a voice waveform becomes a ticket card with:
  `OP-MED · critical · T1 Poarta 6 · Medical`.
- Animation: sentence/card wipe; fields appear one by one.
- Speaker note: one report should create one shared object, instantly.

### 4. Live demo
- Visual: three screenshots in a row:
  `docs/screenshots/02_reporter_voice.png`,
  `docs/screenshots/07_dispatcher_queue.png`,
  `docs/screenshots/13_dashboard_queue.png` (or 10/11 crew).
- Add step labels: **Raportează**, **Clasifică**, **Dispecerizează**, **Rezolvă**.
- Animation: screenshots slide/scale in; labels appear sequentially; highlight
  rings on one ticket.
- Speaker note: tell the story of one incident moving across the system.

### 5. AI that knows its limits
- Headline: “AI local. Decizii verificabile.”
- Left: pipeline: voice → Whisper → Ollama → closed taxonomy → ticket.
- Right: trust rules: “16 tipuri închise”, “schema + guards”, “fallback local”,
  “un singur re-ask, apoi meniul 8×8×8”.
- Animation: nodes → confidence bar → repeat chip → menu fallback.
- Speaker note: emphasize no cloud, no invented codes, no infinite retry.

### 6. Dispatch logic
- Headline: “Fiecare incident își găsește oamenii.”
- Visual: a ticket fanning out to Medical, Security, Fire/Rescue; standby cards
  remain dim.
- Copy: “un responder per departament primar · standby doar pentru context”.
- Animation: ticket → primary cards light up → check marks → quorum completes.
- Speaker note: quorum and notification scoping are the operational core.

### 7. Trust, persistence and safety
- Four compact proof tiles:
  - **Local-first** — TLS pinned, no cloud;
  - **Persistent** — SQLite survives restart;
  - **Location-aware** — 2 km airport geofence;
  - **Anti-farming** — 2 / 5 points, 0 for self-farmed low/medium.
- Small screenshots optional: `18_live_gps.png`, `23_dashboard_statistics.png`.
- Animation: tiles wipe in; lock shield settles.
- Speaker note: production safety concerns were designed in, not bolted on.

### 8. Proof in numbers
- Use exact numbers only:
  - **512** combos (8×8×8)
  - **16** incident types
  - **190** Flutter tests
  - **22** backend tests
  - **108/108** smoke checks
- Visual: one large number per cluster, with a tiny label; maybe two screenshots:
  `23_dashboard_statistics.png`, `24_phone_statistics.png`.
- Animation: bars/panels grow; numbers appear; no fake count-up.
- Speaker note: “tested live on multiple devices, not just mocked screens”.

### 9. Architecture
- One clean diagram:
  `Flutter reporter/crew` → `FastAPI :8443` → `SQLite`;
  `FastAPI` ↔ `Ollama` / `faster-whisper`;
  `FastAPI` → `WSS` → `dashboard + crew phones`.
- Keep it legible; no more than 8 nodes.
- Animation: nodes fade in; connectors wipe; SQLite and WSS arrows last.
- Speaker note: explain why local, why async, why WebSocket.

### 10. What’s next
- Headline: “De la demo la operațiuni reale.”
- Three restrained roadmap items:
  - production auth / RBAC / audit;
  - Postgres + object storage for photos;
  - real dispatch integrations + push notifications.
- Close with the product line:
  **“Un raport. Oamenii potriviți. În timp real.”**
- Animation: roadmap items stack in; logo settles; tagline last.
- Speaker note: honest about demo scope and clear about the next step.

## Assets in the repo

Prefer these current screenshots (do not use older demo-labeled variants):

- `docs/screenshots/00_app_icon.png`
- `docs/screenshots/01_login.png`
- `docs/screenshots/02_reporter_voice.png`
- `docs/screenshots/03_menu_categories_4x2.png`
- `docs/screenshots/07_dispatcher_queue.png`
- `docs/screenshots/10_crew_queue.png`
- `docs/screenshots/11_crew_joined.png`
- `docs/screenshots/13_dashboard_queue.png`
- `docs/screenshots/18_live_gps.png`
- `docs/screenshots/20_account_points.png`
- `docs/screenshots/23_dashboard_statistics.png`
- `docs/screenshots/24_phone_statistics.png`

If a screenshot contains text that is visibly outdated, crop around the UI that
still communicates the feature; do not invent a replacement. If you cannot
access these files, ask me to upload them before designing.

## Technical implementation requirements

- Build a real `.pptx`, not an image sequence, video, HTML slideshow or Canva link.
- Use native PowerPoint **shapes, text boxes, images, animations and slide
  transitions** so the deck remains editable.
- Preferred pipelines:
  1. **PptxGenJS** with native animation XML/capabilities if available;
  2. **python-pptx** for layout plus carefully injected `<p:timing>` animation
     XML for fade/wipe effects;
  3. **PowerPoint COM on Windows** if the environment has PowerPoint and can
     verify the result.
  Choose the most reliable option, and state which one you used.
- Do not simply duplicate one slide into many frames for animation. Native
  animation is required.
- Keep the deck under ~30 MB if possible; compress screenshots sensibly.
- Use only fonts available on a standard Windows machine. If a font is missing,
  fall back to Segoe UI; do not leave a broken font reference.
- Put speaker notes on every slide (Romanian, 1–3 sentences, natural spoken
  language, not a script read verbatim).
- Keep text inside safe margins; no clipped text, no overlapping cards, no
  unreadable small print.
- Use the exact facts above; do not claim production readiness, real customers,
  cloud deployment or metrics that do not exist.

## Verification before returning

1. Open the `.pptx` in PowerPoint and enter **Slide Show**; confirm the key
   animations actually play in the intended order.
2. Export `Wingman_Pitch.pdf` and check no text is clipped.
3. Confirm every slide has speaker notes and that all numbers match this brief.
4. Confirm the deck is 16:9 and does not rely on external assets at runtime.
5. Report: file paths, build command, animation approach, any known limitation.

## Response format

Return:

- the exact file paths you created;
- a one-paragraph description of the visual concept;
- the animation approach and how animations were verified;
- a short list of anything I must review manually (e.g. font substitution or
  a screenshot crop).

Do not dump the full deck content in chat; deliver the files.
