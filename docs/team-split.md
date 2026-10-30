# Team split — who owns what, and how to explain it

## 1. The split (frozen in `CONTRACTS.md` §1)

Wingman was built as **four vertical slices over one frozen contract layer**. Nobody waits for
the others because the interfaces were written before any screen:

| Owner | Files they own | What that means in the product |
|---|---|---|
| **Lead (you)** | `lib/core/**`, `lib/main.dart`, `backend/**`, `scripts/**`, `docs/**` | taxonomy, models, API/WSS client, role routing, FastAPI backend, Ollama classification, faster-whisper STT, TLS/certs, APKs, verification suite, integration |
| **Cutulescu Andrei-Rares** | `lib/features/reporter/**` | the reporter experience: voice recording → `/api/transcribe` → conversation `/api/analyze` → menu fallback → submit |
| **Fita Redu Mihai** | `lib/features/dispatcher/**` | the dispatcher experience: live ticket list, 5-second override card, confirm / deny / reclassify |
| **Lica Rares Adelin** | `lib/features/crew/**` | the crew experience: dispatched list, join („Preia"), vote to resolve, quorum progress |
| **Design** | (to assign) | Material 3 theme + tokens in `lib/core/theme`, screen polish, pitch visuals |

Rule that made it work: **only the Lead edits core, backend, main.dart**; feature owners only touch their
feature folder and ask for contract changes instead of hacking around them.

## 2. Status right now (honest)

| Owner | Status | Evidence |
|---|---|---|
| Lead | ✅ done: contracts, backend, AI, STT, TLS, APKs, phone bring-up, gates | `smoke 58/58`, live Dart 7/7, phone shows „Server conectat" |
| Lica Rares Adelin | ✅ merged: crew „Preia"/„Rezolvat" verified on phone (join, vote, quorum → resolved over WSS); airport-ops UI polish + Chrome preview + widget tests | branches `feat/crew` (`0440163`, `5de1d6a`, `5fee0df`) |
| Cutulescu Andrei-Rares | ✅ merged + verified on phone: type-to-report creates a real ticket (SF-FIRE 95% critical) with follow-ups and confirmation; 3 test suites | branch `feat/reporter` (`5b7e2c9`), 24 files / 5k lines |
| Fita Redu Mihai | ✅ merged: full dispatcher dashboard (live/demo modes, urgency counters, department strip, override countdown card, timeline, zones, filters, history, keyboard shortcuts) + Windows runner. Verified live data + override card on phone. **Mobile-layout caveat:** phone opens in Demo mode by default and the action buttons sit below the fold/under the gesture bar (designed for the Windows dashboard) | branch `feat/dispatcher` (`60051a3`, `f563740`), 14 files / 4.5k lines |
| Design | ⏳ not started | shell is default Material 3 |

Attribution from commit authors: Cutulescu Andrei-Rares = `rarescu08`, Fita Redu Mihai = `Radu <radu.fita2000@gmail.com>`; Lica Rares Adelin's commits carry the demo-machine identity — fix with a `TEAM.md` and their own `git config` before submitting.

Before judging, each owner should push their branch with **their own git identity** so the
commit history shows real authorship (`git config user.name/user.email` locally), and we add a
`TEAM.md` with names. Right now every commit is authored by the same account because the demo
machine's identity was reused.

## 3. How to explain it (judges / submission form)

The story is not „we split screens", it is:

> „We split the product into four independent vertical slices over a frozen contract layer:
> the Lead built the shared core, backend, local AI and deployment; each teammate built one
> role's complete experience against that contract. That let us code in parallel with zero
> merge conflicts — integration took minutes, not hours."

### One-liner per person (Romanian, for the pitch)

- **Lead:** „Am construit stratul comun: taxonomia închisă de 14 tipuri, contractele, backend-ul
  FastAPI cu WebSocket, clasificarea locală cu Qwen2.5 și transcrierea vocală cu Whisper — totul
  pe laptop, offline. Am făcut și certificatul TLS, APK-urile și verificarea end-to-end."
- **F1:** „Am construit fluxul raportorului: înregistrare vocală, transcriere prin serverul local,
  conversație ghidată cu maximum 3 întrebări de clarificare, fallback pe meniul cu 14 butoane."
- **F2:** „Am construit ecranul dispecerului: lista live peste WebSocket, cardul de override de
  5 secunde pentru tichetele cu încredere mică, confirmare/respingere/reclasificare."
- **F3:** „Am construit fluxul echipajului: preluarea tichetelor, votul de rezolvare și progresul
  către quorum, sincronizat în timp real pe toate telefoanele."

### Demo speaking order (one screen each)

1. **F1** reports by voice (or menu) → ticket appears.
2. **F2** shows the 5 s override window, confirms or reclassifies.
3. **F3** joins + votes from a phone; the ticket resolves live on all phones.
4. **Lead** closes: local AI (no cloud), offline-capable backend, TLS pinning, fallback paths,
   measured latency, and the verification suite behind it (`smoke 56/56`, live 7/7).

## 4. What each person can truthfully claim

| Person | Can claim |
|---|---|
| Lead | AI pipeline design (prompt + deterministic guards), local STT, WSS protocol, FastAPI backend, TLS/CA pinning, Android bring-up, test harness, integration, project management |
| F1 | conversational UX, voice flow, clarification logic on the client, menu fallback, submit path |
| F2 | dispatcher decision UX, 5-second override handling, realtime list, wire-contract-aware state updates |
| F3 | crew coordination UX, join/vote state machine, quorum feedback, realtime resolution display |
| Design | Material 3 design system, tokens, screen polish, pitch deck/visuals |

## 5. Before submission

- [ ] F1 and F2 push their branches (even WIP) with their own git identity.
- [ ] Add `TEAM.md`: full names + GitHub usernames + per-person contribution lines.
- [ ] Design owner assigned (theme in `lib/core/theme`, screens follow the tokens).
- [ ] Record the 4-step demo flow once, so the pitch matches the actual app.








