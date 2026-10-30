# Note pentru Lead (de la Friend 1 / reporter)

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
