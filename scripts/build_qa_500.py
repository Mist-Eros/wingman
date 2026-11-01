"""Builds the 500-question Wingman interview/demo prep document.

The individual section files in docs/qa/ are the source of truth; this script
numbers the questions globally and refuses to build unless there are exactly
500 Q/A pairs.
"""

from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
QA_DIR = ROOT / "docs" / "qa"
OUT = ROOT / "docs" / "Wingman-500-Intrebari-si-Raspunsuri.md"

SECTIONS = (
    ("Produs, problemă și pitch", "s01.md"),
    ("Roluri, conturi și permisiuni", "s02.md"),
    ("Taxonomie, meniu și raportare", "s03.md"),
    ("AI, Whisper și LLM", "s04.md"),
    ("Dispecerat, quorum și timp real", "s05.md"),
    ("Recompense, statistici și timere", "s06.md"),
    ("UI/UX, limbă și accesibilitate", "s07.md"),
    ("Backend, arhitectură și securitate", "s08.md"),
    ("Testare, demo și depanare", "s09.md"),
    ("Interviu, tradeoff-uri și roadmap", "s10.md"),
)


def read_pairs(path: Path) -> list[tuple[str, str]]:
    pairs: list[tuple[str, str]] = []
    question: str | None = None
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line:
            continue
        if line.startswith("Q: "):
            if question is not None:
                raise ValueError(f"{path}: Q before A: {question!r}")
            question = line[3:].strip()
        elif line.startswith("A: "):
            if question is None:
                raise ValueError(f"{path}: A without Q: {line!r}")
            pairs.append((question, line[3:].strip()))
            question = None
        else:
            raise ValueError(f"{path}: unexpected line: {line!r}")
    if question is not None:
        raise ValueError(f"{path}: dangling question: {question!r}")
    return pairs


CHEAT_SHEET = """
## Fapte-cheie de memorat

### Stack
- **Mobil:** Flutter/Dart, Android.
- **Backend:** FastAPI/Python, REST + WSS, TLS pe portul `8443`.
- **Persistență:** SQLite, `backend/data/wingman.db`; persistă între reporniri.
- **AI local:** Ollama `qwen2.5:1.5b` pentru clasificare; faster-whisper `small` pe CPU, int8, pentru voce.
- **Control room:** dashboard web separat, care citește același backend.

### Produs
- 10 conturi demo: `admin` + 9 departamente.
- 16 tipuri de incidente într-o taxonomie închisă.
- Meniu 8×8×8 = **512 combinații**.
- Urgențe: `low`, `medium`, `high`, `critical` (verde, galben, portocaliu, roșu).
- Stări: `dispatched`, `in_progress`, `pending_resolution`, `resolved`, `denied`.
- Regula de quorum: un responder per departament primar.
- High/critical: quorum → `pending_resolution` → confirmare admin → `resolved`.
- Low/medium: quorum → `resolved` direct.
- Rewards: **2 puncte** raportare, **5 puncte** join + rezolvare; UI cu două categorii, Raportare și Rezolvare.

### Demo
- Seed: **1 low** (`OP-OTHER`), **1 medium** (`SF-SPILL`), **2 high** (`SC-BAG`, `SC-ITEM`), **1 critical** (`SF-FIRE`).
- `SF-FIRE` are 2 departamente primare și cere 2 responderi; celelalte 4 cazuri au quorum 1 în seed.
- Dashboardul și telefonul partajează backendul în modul live.
- Build local mock: board în memorie, fără REST/WSS, switch din login: **Treci pe Local / Live**.

### Teste
- **198 teste Flutter**
- **24 teste backend**
- **111/111 smoke checks**
- `flutter analyze` curat.

### Comenzi utile
```powershell
# backend
cd backend
.venv\\Scripts\\python.exe -m uvicorn app.main:app --host 0.0.0.0 --port 8443 ^
  --ssl-keyfile certs/server.key --ssl-certfile certs/server.crt

# teste
flutter analyze
flutter test
cd backend; .venv\\Scripts\\python.exe -m unittest discover -s tests

# seed + smoke
python backend\\seed_demo.py --base https://127.0.0.1:8443
python scripts\\smoke_test.py --base https://127.0.0.1:8443

# local mock APK
flutter build apk --release --dart-define=LOCAL_MOCK=true ^
  --dart-define=API_BASE=https://127.0.0.1:8443 ^
  --dart-define=API_TOKEN=demo-token
```

### Endpointuri principale
- `POST /api/reports`
- `POST /api/analyze`
- `POST /api/transcribe`
- `GET /api/tickets`
- `POST /api/tickets/{id}/join`
- `POST /api/tickets/{id}/vote`
- `POST /api/tickets/{id}/leave`
- `POST /api/tickets/{id}/deny`
- `POST /api/tickets/{id}/override`
- `POST /api/tickets/{id}/resolution-confirm`
- `PATCH /api/tickets/{id}`
- `GET /api/stats?period=day|week|month|year`
- `GET /api/health`
- `WS /ws`

### Limite pe care trebuie să le spui sincer
- Autentificarea este demo (conturi hardcodate + token partajat), nu SSO/MFA de producție.
- Modul local este in-memory și nu se sincronizează cu dashboardul.
- Localizarea completă RO/EN este pentru fluxul de raportare; ecranele de crew/dispecer sunt încă în română.
- AI-ul este un model mic local; are gărzi, fallback și verificare umană, nu garanții de producție.
- Sistemul este single-node; scalarea cere altă arhitectură.
"""


def main() -> int:
    all_sections: list[tuple[str, list[tuple[str, str]]]] = []
    total = 0
    for title, filename in SECTIONS:
        pairs = read_pairs(QA_DIR / filename)
        if len(pairs) != 50:
            raise SystemExit(f"{filename}: expected 50 pairs, found {len(pairs)}")
        total += len(pairs)
        all_sections.append((title, pairs))
    if total != 500:
        raise SystemExit(f"expected 500 total pairs, found {total}")

    out: list[str] = []
    out.append("# Wingman — 500 de întrebări și răspunsuri")
    out.append("")
    out.append(
        "**Material de pregătire pentru demo și interviu.** "
        "500 de întrebări cu răspunsuri scurte, tehnice și non-tehnice, "
        "structurate pe produs, operațiuni, AI, backend, testare și business."
    )
    out.append("")
    out.append(
        "> Document generat din `docs/qa/` și verificat automat să conțină "
        "**exact 500** de perechi întrebare–răspuns. Faptele reflectă build-ul "
        "cu commit-ul `55f52fc` și starea demo curentă."
    )
    out.append("")
    out.append("## Cum îl folosești")
    out.append("")
    out.append(
        "1. Citește întâi **Fapte-cheie de memorat** (la final) — sunt numerele "
        "și comenzile pe care le repeți înainte de demo."
    )
    out.append(
        "2. Pentru interviu, exersează secțiunile 1, 2, 5 și 10 cu voce tare."
    )
    out.append(
        "3. Pentru întrebări tehnice, folosește secțiunile 3, 4, 8 și 9."
    )
    out.append(
        "4. Nu învăța răspunsurile pe de rost: învață cele 4–5 principii și "
        "reformulează."
    )
    out.append("")
    out.append("## Cuprins")
    out.append("")
    for idx, (title, _pairs) in enumerate(all_sections, start=1):
        anchor = f"{idx}. {title}".lower().replace(" ", "-").replace(",", "").replace("ș", "s").replace("ă", "a").replace("î", "i").replace("â", "a").replace("ț", "t").replace("–", "").replace("—", "")
        out.append(f"{idx}. [{title}](#{anchor}) — 50 întrebări")
    out.append("")
    out.append("[Fapte-cheie de memorat](#fapte-cheie-de-memorat)")
    out.append("")
    out.append("---")
    out.append("")

    number = 0
    for section_idx, (title, pairs) in enumerate(all_sections, start=1):
        out.append(f"## {section_idx}. {title}")
        out.append("")
        for question, answer in pairs:
            number += 1
            out.append(f"### {number}. {question}")
            out.append("")
            out.append(f"**Răspuns:** {answer}")
            out.append("")
    out.append("---")
    out.append(CHEAT_SHEET.strip())
    out.append("")
    OUT.write_text("\n".join(out).rstrip() + "\n", encoding="utf-8")
    print(f"wrote {OUT} with {number} Q/A pairs")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
