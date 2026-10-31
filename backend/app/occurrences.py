"""Occurrence catalog — official source-backed database of possible incidents.

Data lives in `app/data/occurrences.json` so it can be edited without touching
Python. Each entry is mapped to one of the 14 operational taxonomy codes, which
keeps the classifier small while giving the product a rich, regulation-aligned
reference of what can actually happen at an airport.

Primary sources (see the JSON `sources` array):
  • Commission Implementing Regulation (EU) 2015/1018 — mandatory occurrence list
  • NASA ASRS Coding Taxonomy — voluntary reporting event types
  • Belgium ground-handling occurrence reporting manual
  • EASA list of occurrences to be mandatorily reported
"""

from __future__ import annotations

import json
from functools import lru_cache
from pathlib import Path
from typing import Any

_DATA_PATH = Path(__file__).resolve().parent / "data" / "occurrences.json"


@lru_cache(maxsize=1)
def catalog() -> dict[str, Any]:
    """Load and cache the JSON catalog."""
    with _DATA_PATH.open(encoding="utf-8") as handle:
        return json.load(handle)


def all_occurrences() -> list[dict[str, Any]]:
    return list(catalog()["occurrences"])


def find_occurrences(
    *,
    code: str | None = None,
    category: str | None = None,
) -> list[dict[str, Any]]:
    items = all_occurrences()
    if code:
        wanted = code.strip().upper()
        items = [item for item in items if item["app_code"] == wanted]
    if category:
        wanted = category.strip().lower()
        items = [item for item in items if item["category"] == wanted]
    return items


def get_occurrence(occurrence_id: str) -> dict[str, Any] | None:
    wanted = occurrence_id.strip().upper()
    for item in all_occurrences():
        if item["id"].upper() == wanted:
            return item
    return None


def validate_catalog(valid_codes: set[str]) -> list[str]:
    """Return a list of structural/problems so startup / smoke can reject bad data."""
    problems: list[str] = []
    data = catalog()
    categories = {c["id"] for c in data.get("categories", [])}
    seen_ids: set[str] = set()

    for item in data.get("occurrences", []):
        occurrence_id = item.get("id", "")
        if not occurrence_id:
            problems.append("occurrence without id")
        elif occurrence_id in seen_ids:
            problems.append(f"{occurrence_id}: duplicate id")
        seen_ids.add(occurrence_id)

        code = item.get("app_code", "")
        if code not in valid_codes:
            problems.append(f"{occurrence_id}: unknown app_code {code!r}")
        if item.get("category") not in categories:
            problems.append(
                f"{occurrence_id}: unknown category {item.get('category')!r}"
            )
        for field in ("name_ro", "name_en", "description_ro", "eu_ref"):
            if not str(item.get(field, "")).strip():
                problems.append(f"{occurrence_id}: empty {field}")
        if not isinstance(item.get("mandatory_eu"), bool):
            problems.append(f"{occurrence_id}: mandatory_eu must be boolean")
        if not item.get("example_ro"):
            problems.append(f"{occurrence_id}: missing example_ro")

    return problems
