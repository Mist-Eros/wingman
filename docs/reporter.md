# Reporter feature — design & integration notes

# Reporter (Cutulescu Andrei-Rares, @rarescu08)

The employee who reports an incident. **Hold the mic and say what happened;
release when you are done.** The app asks only for what is missing, then shows
what it understood, and sends the ticket.

Entry point (frozen by `CONTRACTS.md`): `reporter_screen.dart` → `ReporterScreen`.
Everything is reached through `CoreScope`; nothing in `lib/core/` was touched.

## Flow

```
hold mic ─► record WAV (16 kHz mono) ─► POST /api/transcribe (Whisper, laptop)
        ─► POST /api/analyze (Ollama)  ─► brain: what is missing?
            ├─ missing ─► ask (spoken + on screen), hold mic to answer ─┐
            └─ complete ─► confirmation ◄───────────────────────────────┘
                 tap a word to correct it · "Reia de la capăt" · change type
                 ─► POST /api/reports   (voice, or the 14-button menu)
```

* Romanian + English (toggle in the app bar); questions are spoken (TTS).
* Fallbacks that always work: the button menu (category → type, no AI) and
  "type instead" (typed text goes through the same pipeline).
* One GPS fix per report (balanced power, no tracking) is attached to the
  location; the place the reporter *says* ("Poarta 12") stays the human label.

## The brain (`brain/`)

| File | What it does |
|---|---|
| `text_utils.dart` | Normalizes text (no diacritics, same length) and number words ("doisprezece") |
| `lexicon.dart` | ~580 RO + EN keyword stems for the 14 types, categories and danger signals |
| `understanding.dart` | Type, place, size, people in danger, count — from what was said |
| `severity.dart` | **Urgency** from the type's floor + danger signals; **confidence** formula; both with reasons |
| `conversation_brain.dart` | What to ask next: only what is missing, **each thing once**, follow-ups per type (spill → size, fire → anyone in danger…), max 3 questions, answers kept verbatim |

Rules that matter: never ask the same thing twice; an answer is always
recorded even if it matches no type; no predefined problem (an unknown type is
*asked*, a category word like "securitate" is enough); the server stays the
classifier of record and the brain still works if it is down.

## Backend it uses

* `POST /api/transcribe` through core's `api.transcribe` (`docs/whisper-contract.md`):
  the clip is a 16 kHz mono WAV (`audio/wav`), the language is the one picked
  with the RO/EN toggle, recordings stop at 30 s.
* `POST /api/analyze` for type / place; the brain decides the follow-up
  questions itself (see below) and only repeats a server question it does not
  already cover.
* Optional, not blocking: server-side urgency escalation with the same rules
  as `brain/severity.dart` and a medical type — see the notes section at the end of this document.

## Tests

```powershell
flutter test test/reporter_brain_test.dart        # understanding + questions
flutter test test/reporter_scenarios_test.dart    # 70 real sentences: type, urgency, place
flutter test test/reporter_controller_test.dart   # push-to-talk flow, edits, errors, screen
```

## Known limits

* Voice was tested only with a synthetic English phrase; Romanian with real
  voices and apron noise is untested.
* Local keyword understanding is a safety net, not a classifier: unusual
  wording falls back to asking the type once.
* iOS builds need a Mac (microphone / location descriptions are already in
  `Info.plist`).


---

## Notes for the Lead

# Note pentru Lead (de la Cutulescu Andrei-Rares / reporter)

## 1. Whisper — mulțumesc, e folosit
Clientul din `reporter` apelează `api.transcribe(wav, mimeType: 'audio/wav',
language: 'ro' | 'en')` (wrapper în `services/whisper_transcriber.dart`). Nu am
mai trimis un contract separat: ce ai făcut în `docs/whisper-contract.md` ne
ajunge. Răspunsuri la întrebările tale:

* **Limba:** o forțăm, din comutatorul RO/EN al aplicației (nu autodetect).
* **Durata clipului:** push-to-talk, deci o decide cel care ține apăsat;
  oprim automat la **30 s** (recomandarea ta: 5–15 s).
* **Gol / silențiu:** `text: ""` → „nu am auzit nimic, mai încearcă".
* **Primul test real pe telefon:** încă NEFĂCUT de mine. Pe laptop am verificat
  doar cu o frază sintetică în engleză (corectă, ~3 s pe CPU) și cu teste Dart
  cu microfon/serviciu simulate.

## 2. Ce NU am atins
`lib/core/**`, `lib/main.dart`, `backend/**`, `scripts/**`, `docs/**`.
În afara folderului meu, doar: `AndroidManifest.xml` (RECORD_AUDIO + locație,
peste blocul tău cu INTERNET), `ios/Runner/Info.plist` (descrieri microfon și
locație), `pubspec.yaml`/`pubspec.lock` (`flutter_tts`, `record`, `geolocator`).

## 3. Cerere opțională (nu blochează): urgență și tip medical

Găsită testând „lava curge în terminalul 3" (aplicația îl clasifica drept
scurgere de lichid, urgență medie).

* `SF-SPILL` are urgență implicită **medie**, deci orice lichid e „medie".
  `escalate_urgency` doar acceptă urgența cerută de LLM; `apply_classification_guards`
  corectează TIPUL, nu urgența; „lava" nu apare în `KEYWORD_RULES`.
* Confidence-ul cu Ollama e numărul pe care și-l dă modelul; în rezerva cu
  cuvinte-cheie e `min(0.58, 0.30 + 0.04·scor)`.
* Aplicația calculează deja local urgența din ce s-a spus
  (`brain/severity.dart`, 70 de fraze RO/EN în `test/reporter_scenarios_test.dart`):
  tipul e **podeaua**; foc/explozie/gaz/lavă, substanțe toxice sau viață în
  pericol → critică; altfel +1 nivel pentru dimensiune mare (+2 uriașă),
  substanță inflamabilă, pistă/platformă/lângă avion, „se extinde", „urgent",
  cineva a căzut; cineva în pericol → minimum ridicată. Fiecare urgență vine cu
  motivele ei. Ca să fie coerent cu serverul, recomand aceeași escaladare
  deterministă pe server, DUPĂ model și DUPĂ garduri (maximul dintre ele).
  Listele de cuvinte sunt în `brain/lexicon.dart` (`kFireExplosionStems`,
  `kLifeStems`, …).
* **Lipsește un tip medical** (leșin, nu respiră, infarct). Aplicația le trece
  la `OP-OTHER` cu urgență critică, dar `OP-OTHER` nu ajunge la
  `Department.medical`. Propun un tip nou sau `Department.medical` în
  departamentele primare ale lui `OP-OTHER`.

Până atunci: urgența afișată pe telefon e maximul dintre serverul tău și
regulile locale, dar tichetul creat are urgența de la server.





