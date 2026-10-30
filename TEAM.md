# Wingman — team

Fill in full names (GitHub handles are known from the repo collaborators). The Lead
should confirm which handle belongs to Friend 1 / Friend 3; commit authors tell us
Friend 1 pushed as `rarescu08` and Friend 2 as `Radu <radu.fita2000@gmail.com>`.

| # | Name | GitHub | Owns | What they built (one line) |
|---|---|---|---|---|
| Lead | _fill in_ | @Mist-Eros | `lib/core/**`, `main.dart`, `backend/**`, `scripts/**`, `docs/**` | Contracts, taxonomy, FastAPI + WSS backend, local Qwen2.5 classification, faster-whisper STT, TLS/CA pinning, design system, APK/deploy pipeline, verification gates |
| Friend 1 | _fill in_ | @rarescu08 (confirm) | `lib/features/reporter/**` | Hold-to-talk reporter: recording → Whisper → conversation brain (max 3 follow-ups) → confirmation → submit, plus menu and typed fallbacks |
| Friend 2 | Radu Fita | @RaduFita23 | `lib/features/dispatcher/**` | Dispatcher dashboard: live/demo modes, urgency counters, department strip, 5-second override card, timeline, zones, filters, history, Windows runner |
| Friend 3 | _fill in_ | @raresr29 or @RaresCut (confirm) | `lib/features/crew/**` | Crew flows: Preia (join), Rezolvat (vote), quorum progress, live resolution, airport-ops UI polish, widget tests |

## What to say in the pitch (30 seconds)

> „We split the product into four vertical slices over a frozen contract layer. The Lead
> built core + backend + local AI + deployment; each teammate built one role's complete
> experience against that contract. That let us work in parallel with zero merge
> conflicts — integration took minutes."

Demo speaking order: Friend 1 reports → Friend 2 decides (5 s override) → Friend 3 joins
and votes → Lead closes with the local-AI / offline / hardening story.

## Attribution note

Before submitting, each teammate should add their own commit (or a line here) using their
own `git config user.name/user.email`; the demo machine's identity was reused, so the
commit history alone does not attribute the feature work.
