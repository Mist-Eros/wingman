#!/usr/bin/env python3
"""Render docs/occurrence-catalog.md from the JSON occurrence database.

Run from the repo root after editing backend/app/data/occurrences.json:

    python scripts/render_occurrence_catalog.py
"""

from __future__ import annotations

import json
from collections import Counter
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
DATA = REPO_ROOT / "backend" / "app" / "data" / "occurrences.json"
OUT = REPO_ROOT / "docs" / "occurrence-catalog.md"


def _cell(value: object) -> str:
    return str(value).replace("|", "\\|").replace("\n", " ").strip()


def main() -> int:
    data = json.loads(DATA.read_text(encoding="utf-8"))
    occurrences = data["occurrences"]
    categories = {item["id"]: item for item in data["categories"]}
    category_order = [item["id"] for item in data["categories"]]
    code_counts = Counter(item["app_code"] for item in occurrences)
    mandatory = sum(1 for item in occurrences if item["mandatory_eu"])

    lines: list[str] = []
    lines.append("# Catalog de incidente aeroportuare (baza de date Wingman)\n")
    lines.append(
        "Bază de date cu incidentele posibile într-un aeroport, aliniată la cadrul "
        "european de raportare și la taxonomia ASRS. Fiecare intrare este mapată pe "
        "unul dintre cele **14 coduri operaționale** Wingman, ca să poată fi "
        "clasificată, dispecerizată și raportată.\n"
    )
    lines.append(
        f"**{len(occurrences)} incidente** · **{len(categories)} categorii** · "
        f"**{mandatory}** marcate ca obligatoriu de raportat în UE (Reg. 2015/1018).\n"
    )
    lines.append(
        "> Sursa de adevăr pentru aplicație este `backend/app/data/occurrences.json`; "
        "acest document este generat din ea. Nu edita tabelul manual — rulează "
        "`python scripts/render_occurrence_catalog.py` după modificarea JSON-ului.\n"
    )

    lines.append("## Surse\n")
    for source in data["sources"]:
        lines.append(f"- **{source['title']}** — <{source['url']}>")
    lines.append("")

    lines.append("## Cum se leagă de Wingman\n")
    lines.append(
        "Wingman rămâne cu un classifier închis de 14 coduri (modelul local mic are "
        "nevoie de puține clase). Catalogul adaugă profunzime și acoperire: fiecare "
        "incident posibil este descris, exemplificat și mapat pe codul operațional "
        "corespunzător, iar API-ul îl poate servi ca referință pentru interfață, "
        "antrenare și raportare.\n"
    )
    lines.append("| Domeniu | Incidente | Coduri operaționale folosite |")
    lines.append("|---|---:|---|")
    for category_id in category_order:
        category = categories[category_id]
        items = [item for item in occurrences if item["category"] == category_id]
        codes = ", ".join(sorted({item["app_code"] for item in items}))
        lines.append(
            f"| {_cell(category['label_ro'])} | {len(items)} | `{_cell(codes)}` |"
        )
    lines.append("")

    lines.append("## Catalog\n")
    for category_id in category_order:
        category = categories[category_id]
        items = [item for item in occurrences if item["category"] == category_id]
        if not items:
            continue
        lines.append(f"### {category['label_ro']} ({len(items)})\n")
        lines.append(f"Referință: {category['eu_annex']}\n")
        lines.append(
            "| ID | Incident | Cod | Obligatoriu UE | Referință UE | Exemplu |"
        )
        lines.append("|---|---|---|---|---|---|")
        for item in items:
            marker = "da" if item["mandatory_eu"] else "nu"
            lines.append(
                "| {id} | **{name}**<br>{en} | `{code}` | {mandatory} | {ref} | {example} |".format(
                    id=_cell(item["id"]),
                    name=_cell(item["name_ro"]),
                    en=_cell(item["name_en"]),
                    code=_cell(item["app_code"]),
                    mandatory=marker,
                    ref=_cell(item["eu_ref"]),
                    example=_cell(item["example_ro"]),
                )
            )
        lines.append("")

    lines.append("## Distribuție pe coduri operaționale\n")
    lines.append("| Cod | Incidente |")
    lines.append("|---|---:|")
    for code, count in sorted(code_counts.items()):
        lines.append(f"| `{code}` | {count} |")
    lines.append("")

    lines.append("## Cum adaugi un incident\n")
    lines.append(
        "1. Adaugă o intrare nouă în `backend/app/data/occurrences.json` "
        "(ID unic `OCC-...`, `app_code` existent, categorie existentă, "
        "`eu_ref`, `mandatory_eu`, aliasuri și un exemplu).\n"
        "2. Rulează `python scripts/render_occurrence_catalog.py`.\n"
        "3. Rulează `python scripts/smoke_test.py --base https://127.0.0.1:8443` "
        "— catalogul este validat la pornirea backend-ului și în smoke test.\n"
    )
    lines.append(
        "## API\n"
        "- `GET /api/occurrences` — tot catalogul (toate intrările + surse + categorii)\n"
        "- `GET /api/occurrences?code=SF-FIRE` — filtrare pe cod operațional\n"
        "- `GET /api/occurrences?category=ground_handling` — filtrare pe domeniu\n"
        "- `GET /api/occurrences/{id}` — o singură intrare\n"
    )

    OUT.write_text("\n".join(lines), encoding="utf-8")
    print(f"wrote {OUT.relative_to(REPO_ROOT)} · {len(occurrences)} entries")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
