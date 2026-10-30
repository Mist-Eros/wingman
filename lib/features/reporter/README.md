# Reporter (Friend 1)

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
  as `brain/severity.dart` and a medical type — see `NOTES_FOR_LEAD.md`.

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
