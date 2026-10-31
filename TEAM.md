# Wingman — team

Names from the hackathon team page; GitHub handles from the repo history.

| Role | Name | GitHub | Owns | What they built |
|---|---|---|---|---|
| Lead / Captain | **Furtuna-Cola Andrei-Alexandru** | @Mist-Eros (team owner) | `lib/core/**`, `lib/main.dart`, `backend/**`, `scripts/**`, `docs/**` | Contracts, taxonomy, FastAPI + WSS backend, local Qwen2.5 classification, faster-whisper STT, TLS/CA pinning, design system, APK/deploy pipeline, verification gates |
| Reporter | **Cutulescu Andrei-Rares** | @rarescu08 (confirmed by commit `5b7e2c9`) | `lib/features/reporter/**` | Hold-to-talk reporter: recording → Whisper → conversation brain (max 3 follow-ups) → confirmation → submit, plus menu and typed fallbacks |
| Dispatcher | **Fita Redu Mihai** | @RaduFita23 (commits `60051a3`, `f563740`) | `lib/features/dispatcher/**` | Dispatcher dashboard: live/demo modes, urgency counters, department strip, open queue, timeline, zones, filters, history, Windows runner |
| Crew | **Lica Rares Adelin** | @RaresCut or @raresr29 (confirm; feature commits `0440163`, `5de1d6a`, `5fee0df` were authored under the shared demo-machine identity) | `lib/features/crew/**` | Crew flows: Preia (join), Rezolvat (vote), quorum progress, live resolution, airport-ops UI polish, widget tests |

## Showcase & timeline

Per-person rendered cards and the work timeline are in **docs/team-timeline.md** and in
`D:\Hackathon\Screenshots\Team`:

- `timeline.png` — one-page timeline for all four people
- `furtuna-lead.png` — Furtuna-Cola Andrei-Alexandru: core, backend, AI, design system, control room
- `cutulescu-reporter.png` — Cutulescu Andrei-Rares: hold-to-talk flow, brain, verification card
- `fita-dispatcher.png` — Fita Redu Mihai: live board, filters
- `lica-crew.png` — Lica Rares Adelin: Preia/Rezolvat, quorum, department scoping

## What to say in the pitch (30 seconds)

> „We split the product into four vertical slices over a frozen contract layer. The Lead
> built core + backend + local AI + deployment; each teammate built one role's complete
> experience against that contract. That let us work in parallel with zero merge
> conflicts — integration took minutes."

Demo speaking order: Cutulescu Andrei-Rares reports → Fita Redu Mihai triages/denies/reclassifies →
Lica Rares Adelin joins and votes → Furtuna-Cola Andrei-Alexandru closes with the local-AI /
offline / hardening story.

## Attribution note

Before submitting, each teammate should add their own commit (or a line here) using their own
`git config user.name/user.email`. Lica Rares Adelin's original feature commits were authored
under the demo-machine identity, so the commit history alone does not attribute the crew work —
the file paths under `lib/features/crew/**` do.
