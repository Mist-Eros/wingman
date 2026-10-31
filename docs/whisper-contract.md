# `/api/transcribe` — gata (voce → text), pentru F1

**Implementat, live și testat.** Smoke test: 56/56 (secțiunea 11). Test live Dart: 7/7.
Rulează local pe laptop (faster-whisper, model `small` int8 pe CPU) — fără cloud, fără API key,
audio-ul nu pleacă din rețeaua locală.

> Nu am primit fișierul `CONTRACT_REQUEST.md` (nu există pe laptopul de backend și repo-ul nu
> are branch/PR de la tine). Implementarea de mai jos respectă cererea așa cum a fost rezumată
> (format, răspuns, sfaturi faster-whisper). Dacă fișierul tău diferă, trimite-l și aliniez în
> ~10 minute — câmpurile sunt izolate în `backend/app/stt.py`.

## Request (JSON — drumul principal, folosit de clientul Dart)

```http
POST /api/transcribe
Authorization: Bearer demo-token
Content-Type: application/json

{
  "audio_base64": "<bytes m4a/wav/mp3, base64>",
  "mime_type": "audio/mp4",
  "language": "ro"
}
```

| Câmp | Obligatoriu | Sens |
|---|---|---|
| `audio_base64` | da | clipul audio encodat base64 (max 25 MB) |
| `mime_type` | nu (default `audio/mp4`) | containerul: `audio/mp4` (m4a), `audio/wav`, `audio/mpeg`, `audio/aac`, `audio/ogg`... |
| `language` | nu | `"ro"` forțează româna; omite / `"auto"` = detectare automată |

## Response

```json
{
  "text": "este fum lângă poarta 12",
  "language": "ro",
  "language_probability": 0.97,
  "duration_ms": 2400,
  "model": "small",
  "provider": "faster-whisper",
  "latency_ms": 1800,
  "words": [
    {"text": "There", "probability": 0.882, "start": 0.0, "end": 0.32},
    {"text": "is", "probability": 0.994, "start": 0.32, "end": 0.48},
    {"text": "smoke", "probability": 0.757, "start": 0.48, "end": 0.91},
    {"text": "gate", "probability": 0.599, "start": 1.24, "end": 1.61}
  ]
}
```

- `text: ""` + HTTP 200 înseamnă „silențiu / nu s-a înțeles nimic" (VAD-ul taie tăcerea) — în UI
  spune „nu am auzit bine, mai încearcă" și lasă userul să reînregistreze sau să treacă pe meniu.
- `400`: base64 invalid sau audio prea mare. `503`: modelul încă nu e descărcat pe server
  (meniul funcționează în continuare).
- Latențe măsurate pe laptopul demo: **cold 1.2 s** (încărcare model ~1 s), **warm ~0.1 s** pentru
  0.5 s de audio. Un clip de 8-10 s => ~1-2 s.

## Cum îl folosești din Dart (deja în core)

```dart
final bytes = await recorder.stop();                    // List<int>, m4a
final stt = await CoreScope.apiOf(context).transcribe(
  bytes,
  mimeType: 'audio/mp4',
  language: 'ro',
);
if (stt.isEmpty) {
  await spune('Nu am auzit bine. Mai încearcă sau alege din meniu.');
  return;
}
// textul intră exact ca în fluxul conversațional:
var tur = await api.analyze(AnalyzeRequest(transcript: stt.text));
```

`api.transcribe` aruncă `ApiException` cu `statusCode` 400/503 și mesaj deja prietenos.

## Curl (fără PowerShell, ca să nu strice UTF-8/JSON)

```powershell
python - <<'PY'
import base64, json, urllib.request
audio = base64.b64encode(open("clip.m4a", "rb").read()).decode()
body = json.dumps({"audio_base64": audio, "mime_type": "audio/mp4", "language": "ro"}).encode()
req = urllib.request.Request(
    "https://192.168.137.1:8443/api/transcribe", data=body,
    headers={"Authorization": "Bearer demo-token", "Content-Type": "application/json"})
print(urllib.request.urlopen(req, context=__import__("ssl").create_default_context(cafile="backend/certs/ca.crt"), timeout=120).read().decode())
PY
```

Varianta multipart pentru curl/automatizare: `POST /api/transcribe/upload` cu un câmp `file`.

## Config server (backend/.env.example)

```
WHISPER_MODEL=small            # tiny/base/small/medium (trade-off viteză/acuratețe)
WHISPER_DEVICE=cpu             # cpu sau cuda
WHISPER_COMPUTE_TYPE=int8
MAX_AUDIO_BYTES=26214400       # 25 MB
```

## Ce rămâne de la tine

1. Trimite `CONTRACT_REQUEST.md` dacă formatul cerut diferă (ex. nume de câmpuri, timestampuri,
   diarizare, răspuns parțial) — adaptez.
2. Confirmă: forțezi `language: "ro"` sau lași autodetect? (acum merge ambele)
3. Confirmă limita de durată a clipului din UI (recomand 5-15 s; peste 20 s crește latența).
4. Pe telefon, primul test real: înregistrezi „este fum lângă poarta 12" și trimiți textul la
   `/api/analyze` — verificăm cap-coadă.


## Word confidence (UI underlining)

`faster-whisper` does not put confidence in the `text` field. We enable
`word_timestamps=True` and return one entry per recognised word:

- `probability`: 0..1, the model's confidence for that word
- `start` / `end`: seconds in the uploaded clip

The reporter app underlines words with `probability < 0.70` and makes **only
those words editable** (tap → correction dialog). High-confidence words are
read-only; if no `words` array is present (old server/typed input), the app
falls back to the legacy editable-all behaviour.

Real fixture result (English, `small`): `gate` 0.599 is underlined; `There`
0.882 / `smoke` 0.757 remain read-only.
