"""Closed incident taxonomy loader.

`backend/taxonomy.json` is GENERATED from `lib/core/incidents/taxonomy.dart`
(the Flutter app's contract file) — never hand-edit it:

    dart run tool/emit_taxonomy.dart --write
    # or, without a Dart SDK:
    python scripts/sync_taxonomy.py --write

The backend refuses to start if the catalog is malformed, so a taxonomy edit
can never silently break the AI contract at 3 a.m.
"""

from __future__ import annotations

import copy
import json
import logging
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from .config import settings

logger = logging.getLogger("airport.taxonomy")

EXPECTED_TYPE_COUNT = 14
EXPECTED_CATEGORY_COUNT = 4

# Must match the `IncidentCategory` enum in taxonomy.dart.
CATEGORIES: dict[str, str] = {
    "safety_fire": "Siguranță și incendiu",
    "security": "Securitate",
    "maintenance": "Mentenanță",
    "operations": "Operațiuni",
}

# Must match the `Urgency` enum in taxonomy.dart (ordered, low → critical).
URGENCY_LEVELS: tuple[str, ...] = ("low", "medium", "high", "critical")
URGENCY_LABELS: dict[str, str] = {
    "low": "Scăzută",
    "medium": "Medie",
    "high": "Ridicată",
    "critical": "Critică",
}

# Must match the `Department` enum in taxonomy.dart.
DEPARTMENTS: frozenset[str] = frozenset(
    {
        "security",
        "fire_rescue",
        "medical",
        "maintenance",
        "operations",
        "terminal",
        "it",
        "baggage",
        "airside",
    }
)


@dataclass(frozen=True)
class IncidentType:
    code: str
    label_ro: str
    category: str
    urgency: str
    primary_departments: tuple[str, ...]
    standby_departments: tuple[str, ...]

    def prompt_line(self) -> str:
        return (
            f"{self.code} | {self.category} | urgency={self.urgency} | "
            f"{self.label_ro} | primary={','.join(self.primary_departments)}"
        )

    def to_wire(self) -> dict[str, Any]:
        return {
            "code": self.code,
            "label_ro": self.label_ro,
            "category": self.category,
            "urgency": self.urgency,
            "primary_departments": list(self.primary_departments),
            "standby_departments": list(self.standby_departments),
        }


class Taxonomy:
    def __init__(self, data: dict[str, Any]) -> None:
        self._raw = data
        self.version = int(data.get("version", 0) or 0)
        self.generated_from = str(data.get("generated_from", ""))

        types_raw = data.get("types")
        if not isinstance(types_raw, list):
            raise RuntimeError("taxonomy.json: 'types' must be a list")

        parsed: list[IncidentType] = []
        for index, item in enumerate(types_raw):
            if not isinstance(item, dict):
                raise RuntimeError(f"taxonomy.json: types[{index}] is not an object")
            try:
                parsed.append(
                    IncidentType(
                        code=str(item["code"]).strip().upper(),
                        label_ro=str(item["label_ro"]).strip(),
                        category=str(item["category"]).strip(),
                        urgency=str(item["urgency"]).strip(),
                        primary_departments=tuple(
                            str(d) for d in item.get("primary_departments", [])
                        ),
                        standby_departments=tuple(
                            str(d) for d in item.get("standby_departments", [])
                        ),
                    )
                )
            except KeyError as exc:
                raise RuntimeError(
                    f"taxonomy.json: types[{index}] is missing field {exc}"
                ) from exc

        self._types: tuple[IncidentType, ...] = tuple(parsed)
        self._by_code: dict[str, IncidentType] = {t.code: t for t in self._types}
        self._validate()

    # ── accessors ─────────────────────────────────────────────────────────
    @property
    def types(self) -> tuple[IncidentType, ...]:
        return self._types

    def codes(self) -> list[str]:
        return [t.code for t in self._types]

    def by_code(self, code: str | None) -> IncidentType | None:
        if not code:
            return None
        return self._by_code.get(str(code).strip().upper())

    def require(self, code: str | None) -> IncidentType:
        incident_type = self.by_code(code)
        if incident_type is None:
            raise KeyError(
                f"Incident code {code!r} is not in the closed taxonomy. "
                f"Allowed: {', '.join(self.codes())}"
            )
        return incident_type

    def by_category(self, category: str) -> list[IncidentType]:
        return [t for t in self._types if t.category == category]

    def prompt_catalog(self) -> str:
        return "\n".join(t.prompt_line() for t in self._types)

    def as_dict(self) -> dict[str, Any]:
        return copy.deepcopy(self._raw)

    def summary(self) -> dict[str, Any]:
        counts = {category: len(self.by_category(category)) for category in CATEGORIES}
        return {
            "version": self.version,
            "generated_from": self.generated_from,
            "incident_types": len(self._types),
            "categories": counts,
        }

    # ── integrity ─────────────────────────────────────────────────────────
    def _validate(self) -> None:
        problems: list[str] = []

        if self.version <= 0:
            problems.append("missing/invalid 'version'")
        if len(self._types) != EXPECTED_TYPE_COUNT:
            problems.append(
                f"expected {EXPECTED_TYPE_COUNT} incident types, "
                f"found {len(self._types)}"
            )

        seen: set[str] = set()
        for incident_type in self._types:
            code = incident_type.code
            if code in seen:
                problems.append(f"{code}: duplicate code")
            seen.add(code)
            if code != code.upper():
                problems.append(f"{code}: code must be uppercase")
            if not incident_type.label_ro:
                problems.append(f"{code}: empty label_ro")
            if incident_type.category not in CATEGORIES:
                problems.append(
                    f"{code}: unknown category {incident_type.category!r}"
                )
            if incident_type.urgency not in URGENCY_LEVELS:
                problems.append(
                    f"{code}: unknown urgency {incident_type.urgency!r}"
                )
            if not incident_type.primary_departments:
                problems.append(f"{code}: no primary departments")
            for department in (
                incident_type.primary_departments + incident_type.standby_departments
            ):
                if department not in DEPARTMENTS:
                    problems.append(f"{code}: unknown department {department!r}")

        for category in CATEGORIES:
            if not self.by_category(category):
                problems.append(f"category {category!r} has no incident types")

        if problems:
            raise RuntimeError(
                "Invalid taxonomy.json — regenerate it from the Dart file "
                "(dart run tool/emit_taxonomy.dart --write). Problems:\n - "
                + "\n - ".join(problems)
            )


_cached: Taxonomy | None = None


def load_taxonomy(path: Path | None = None) -> Taxonomy:
    global _cached
    target = path or settings.taxonomy_path
    if _cached is not None:
        return _cached
    if not target.exists():
        raise RuntimeError(
            f"Taxonomy file not found: {target}\n"
            "Generate it from the Flutter contract file:\n"
            "  dart run tool/emit_taxonomy.dart --write\n"
            "  (or) python scripts/sync_taxonomy.py --write"
        )
    data = json.loads(target.read_text(encoding="utf-8"))
    _cached = Taxonomy(data)
    return _cached


def get_taxonomy() -> Taxonomy:
    return load_taxonomy()
