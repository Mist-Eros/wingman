# Contract `/api/analyze` — fluxul conversațional (F1)

Stare: **implementat, live și testat** (smoke test 50/50, test live Dart↔backend 7/7).
Fișiere: `backend/app/ai.py::analyze_conversation`, `backend/app/main.py`, `backend/app/schemas.py::AnalyzeIn`,
`lib/core/models/analyze_result.dart`, `lib/core/api/api_client.dart::analyze`.

> Dacă specificația ta de slot-filling folosește alte nume de sloturi sau alt format, trimite-o —
> alinierea durează ~10 minute. Contractul de mai jos acoperă `fields` + `missing` + `question`
> exact cum ai cerut și e deja testat end-to-end din clientul Dart.

## 1. Un tur = un request

Aplicația trimite **tot textul acumulat** (nu doar ultimul răspuns), numărul de întrebări deja
puse și, opțional, codul confirmat într-un tur anterior. Serverul răspunde cu ce a înțeles, ce
lipsește și următoarea întrebare de afișat **și rostit**.

```http
POST /api/analyze
Authorization: Bearer demo-token
Content-Type: application/json
```

```json
{
  "transcript": "tot ce s-a spus până acum, în ordine",
  "location": {"terminal": "", "zone": "", "lat": null, "lng": null, "note": null},
  "hint_code": null,
  "clarifications_asked": 0,
  "known_incident_code": null
}
```

| Câmp | Tip | Sens |
|---|---|---|
| `transcript` | string (1..4000) | tot textul conversației, concatenat |
| `location` | obiect | locația structurată dacă o ai din UI (poate rămâne goală) |
| `hint_code` | string \| null | cod ales din meniu (dacă userul a sărit peste conversație) |
| `clarifications_asked` | int 0..10 | câte întrebări ai pus deja (serverul se oprește la 3) |
| `known_incident_code` | string \| null | `fields.incident_code` din turul anterior, ca să nu-l pierzi |

## 2. Răspuns

```json
{
  "fields": {
    "incident_code": "SF-FIRE",
    "label_ro": "Foc sau fum în terminal",
    "location": "Terminal 1",
    "people_at_risk": null,
    "urgency": "critical",
    "confidence": 0.82,
    "ai_source": "ollama",
    "rationale": "fum în terminal"
  },
  "missing": ["location"],
  "question": "Unde se întâmplă exact? (terminal, poartă sau zonă)",
  "clarifications_asked": 0,
  "max_clarifications": 3,
  "ready": false,
  "classification": {
    "incident_code": "SF-FIRE", "urgency": "critical", "confidence": 0.82,
    "rationale": "fum în terminal", "ai_source": "ollama", "latency_ms": 1200
  },
  "taxonomy_version": 1
}
```

| Câmp | Sens |
|---|---|
| `fields.incident_code` | cod din taxonomie sau `null` dacă nu s-a putut încadra |
| `fields.label_ro` | eticheta românească pentru UI |
| `fields.location` | text liber extras (`"Poarta 12"`, `"Terminal 1"`, `""`) |
| `fields.people_at_risk` | `true` / `false` / `null` (necunoscut) |
| `fields.urgency` | `low` · `medium` · `high` · `critical` |
| `fields.confidence` | 0..1 (dacă serverul s-a oprit cu goluri → max 0.40) |
| `missing` | sloturile obligatorii lipsă: `incident_code`, `location` |
| `question` | textul de afișat **și rostit**; `null` = poți trimite |
| `clarifications_asked` / `max_clarifications` | contor + limita (3) |
| `ready` | `true` ⇔ `question == null` |
| `classification` | snapshot-ul complet (util pentru debug/telemetrie) |

## 3. Reguli impuse de server (nu le duplica în UI)

1. **Maximum 3 întrebări.** La `clarifications_asked >= 3` răspunsul vine cu `question: null`.
2. **Incertitudine ⇒ dispecer.** Dacă se oprește cu sloturi lipsă sau `confidence < 0.65`,
   `fields.confidence` este plafonat la **0.40**, deci tichetul intră automat în fereastra de
   5 secunde a dispecerului.
3. Ordinea întrebărilor: tip incident → locație → detaliu (dacă încrederea e mică) →
   „Este cineva în pericol?” (doar pentru `high`/`critical`).
4. **Meniul cu butoane e mereu fallback**: `hint_code` + `use_ai: false` direct la
   `/api/reports`, fără întrebări și fără latență AI.
5. `extra="forbid"` pe request: trimite exact câmpurile de mai sus.

## 4. Cum îl folosești din Dart (deja implementat în core)

```dart
final api = CoreScope.apiOf(context);
var acumulat = <String>[];
var tur = await api.analyze(AnalyzeRequest(transcript: acumulat.join(' ')));

while (tur.needsMoreInfo) {
  await arataSiVorbeste(tur.question!);           // UI + TTS
  final raspuns = await ascultaSauPrimeazaText(); // STT sau text
  acumulat.add(raspuns);
  tur = await api.analyze(AnalyzeRequest(
    transcript: acumulat.join(' '),
    clarificationsAsked: tur.clarificationsAsked + 1,
    knownIncidentCode: tur.fields.incidentCode,
  ));
}

// ready: trimite raportul final (clasificarea se reface pe server la /reports)
final tichet = await api.report(ReportDraft(
  source: ReportSource.voice,
  transcript: acumulat.join(' '),
  reporterId: CoreScope.sessionOf(context).userId,
  reporterName: CoreScope.sessionOf(context).displayName,
));
```

Helpers disponibili pe `AnalyzeResult`: `needsMoreInfo`, `asksForLocation`, `asksForType`,
`ready`, `fields.incidentType`, `fields.confidenceLabel`, `summary`.

> Sfat demo: la al doilea tur poți afișa deja cardul „Am înțeles: …” folosind `tur.summary`,
> ca judecătorii să vadă progresul conversației.

## 5. Test rapid din terminal

```powershell
$body = @{ transcript = "Este un miros intepator langa poarta 12"; clarifications_asked = 0 } | ConvertTo-Json
curl.exe -sS -X POST "https://192.168.0.170:8443/api/analyze" `
  -H "Authorization: Bearer demo-token" -H "Content-Type: application/json" `
  --data-binary $body
```

Sau, fără probleme de encoding PowerShell:

```powershell
python scripts\smoke_test.py --ca backend\certs\ca.crt    # secțiunea [10]
```

## 6. Taxonomia pentru meniul cu butoane

Nu copia lista — import-o din `lib/core/incidents/taxonomy.dart` (e contractul):

```dart
import '../../core/incidents/taxonomy.dart';

for (final category in IncidentCategory.values) {          // 4 categorii
  for (final type in IncidentTaxonomy.byCategory(category)) { // tipurile din ea
    ListTile(
      title: Text(type.labelRo),                           // "Foc sau fum în terminal"
      subtitle: Text('${type.code} · ${type.urgency.labelRo}'),
      trailing: Icon(Icons.chevron_right),
      onTap: () => trimite(hintCode: type.code),           // -> /api/reports use_ai:false
    );
  }
}
```

Cele 15 tipuri (cod · etichetă · urgență): `SF-FIRE` Foc sau fum în terminal (critical) ·
`SF-FOD` Corp străin pe platformă/cale de rulare (critical) · `SF-SPILL` Scurgere de lichid (medium) ·
`SF-EQUIP` Echipament de stingere defect (high) · `SC-BAG` Bagaj nesupravegheat (high) ·
`SC-ACCESS` Acces neautorizat (critical) · `SC-ITEM` Obiect interzis (high) ·
`SC-BEHAV` Comportament suspect (high) · `MT-BELT` Bandă bagaje (high) ·
`MT-ESC` Escalator/lift (medium) · `MT-JBRIDGE` Pasarelă de îmbarcare (high) ·
`OP-QUEUE` Aglomerare securitate (medium) · `OP-IT` Cădere sistem IT (high) ·
`OP-OTHER` Alt incident – catch-all (low).
