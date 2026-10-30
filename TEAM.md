# Wingman — team

| Role | Name | GitHub | Owns | What they built |
|---|---|---|---|---|
| Lead | _name to fill_ | @Mist-Eros | `lib/core/**`, `lib/main.dart`, `backend/**`, `scripts/**`, `docs/**` | Contracts, taxonomy, FastAPI + WSS backend, local Qwen2.5 classification, faster-whisper STT, TLS/CA pinning, design system, APK/deploy pipeline, verification gates |
| Reporter | _name to fill_ | @rarescu08 (confirmed by commit `5b7e2c9`) | `lib/features/reporter/**` | Hold-to-talk reporter: recording → Whisper → conversation brain (max 3 follow-ups) → confirmation → submit, plus menu and typed fallbacks |
| Dispatcher | Radu Fita | @RaduFita23 (commits `60051a3`, `f563740`) | `lib/features/dispatcher/**` | Dispatcher dashboard: live/demo modes, urgency counters, department strip, 5-second override card, timeline, zones, filters, history, Windows runner |
| Crew | Rares | @RaresCut or @raresr29 (confirm; feature commits `0440163`, `5de1d6a`, `5fee0df` were authored under the shared demo-machine identity) | `lib/features/crew/**` | Crew flows: Preia (join), Rezolvat (vote), quorum progress, live resolution, airport-ops UI polish, widget tests |

## Showcase & timeline

A visual per-person showcase and the work timeline live in **docs/team-timeline.md**; the rendered
cards are in `D:\Hackathon\Screenshots\Team`:

- `timeline.png` — one-page timeline for all four people
- `lead.png` — Lead: core, backend, AI, design system, control room
- `rarescu08-reporter.png` — Reporter: hold-to-talk flow, brain, verification card
- `radu-fita-dispatcher.png` — Dispatcher: live board, 5-second override, filters
- `rares-crew.png` — Crew: Preia/Rezolvat, quorum, department scoping

## What to say in the pitch (30 seconds)

> „We split the product into four vertical slices over a frozen contract layer. The Lead
> built core + backend + local AI + deployment; each teammate built one role's complete
> experience against that contract. That let us work in parallel with zero merge
> conflicts — integration took minutes."

Demo speaking order: the reporter reports → the dispatcher decides (5 s override) → the crew
joins and votes → the Lead closes with the local-AI / offline / hardening story.

## Attribution note

Before submitting, each teammate should add their own commit (or a line here) using their own
`git config user.name/user.email`. Rares' original feature commits were authored under the demo
machine identity, so the commit history alone does not attribute the crew work — the file paths
under `lib/features/crew/**` do.
