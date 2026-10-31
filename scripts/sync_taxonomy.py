"""Keeps `backend/taxonomy.json` in lock-step with the Flutter contract file.

`lib/core/incidents/taxonomy.dart` is the single source of truth. This script
parses it (no Dart SDK needed) and either writes the backend catalog or verifies
that the existing one has not drifted.

Run from the repo root:

    python scripts/sync_taxonomy.py            # verify only (CI / pre-merge)
    python scripts/sync_taxonomy.py --write    # regenerate backend/taxonomy.json

Exit codes: 0 = in sync · 1 = drift/invalid taxonomy · 2 = file not found.

Why this exists: if the app's closed list and the list injected into the Ollama
prompt differ even by one code, the model can return a code the app cannot
render — and that bug only shows up during the demo. This check makes it
impossible to merge.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any

REPO_ROOT = Path(__file__).resolve().parent.parent
DART_PATH = REPO_ROOT / "lib" / "core" / "incidents" / "taxonomy.dart"
JSON_PATH = REPO_ROOT / "backend" / "taxonomy.json"

EXPECTED_CATEGORIES = {"safety_fire", "security", "maintenance", "operations"}
EXPECTED_URGENCIES = {"low", "medium", "high", "critical"}


class TaxonomyParseError(RuntimeError):
    pass


def _read(path: Path) -> str:
    if not path.exists():
        raise FileNotFoundError(f"{path} not found")
    return path.read_text(encoding="utf-8")


def parse_enum(source: str, name: str) -> dict[str, str]:
    """Returns {member: wire} for an enhanced enum like:
    enum Urgency { low('low', 'Scăzută', 1), ... }
    """
    match = re.search(r"enum\s+" + re.escape(name) + r"\s*\{(.*?)\n\}", source, re.S)
    if not match:
        raise TaxonomyParseError(f"could not find `enum {name}`")
    body = match.group(1)
    members: dict[str, str] = {}
    for entry in re.finditer(r"^\s*(\w+)\('([^']*)'", body, re.M):
        members[entry.group(1)] = entry.group(2)
    if not members:
        raise TaxonomyParseError(f"`enum {name}` has no entries")
    return members


def parse_types(source: str) -> list[dict[str, Any]]:
    match = re.search(
        r"static const List<IncidentType> all = <IncidentType>\[(.*?)\n  \];",
        source,
        re.S,
    )
    if not match:
        raise TaxonomyParseError(
            "could not find `static const List<IncidentType> all = <IncidentType>[ ... ];`"
        )
    chunks = re.split(r"IncidentType\(", match.group(1))[1:]
    if not chunks:
        raise TaxonomyParseError("no `IncidentType(...)` entries found")

    parsed: list[dict[str, Any]] = []
    for index, chunk in enumerate(chunks):
        code_match = re.search(r"code:\s*'([^']+)'", chunk)
        label_match = re.search(r"labelRo:\s*'([^']+)'", chunk)
        category_match = re.search(r"category:\s*IncidentCategory\.(\w+)", chunk)
        urgency_match = re.search(r"urgency:\s*Urgency\.(\w+)", chunk)
        primary_match = re.search(
            r"primaryDepartments:\s*<Department>\[([^\]]*)\]", chunk
        )
        standby_match = re.search(
            r"standbyDepartments:\s*<Department>\[([^\]]*)\]", chunk
        )
        missing = [
            field_name
            for field_name, field_match in (
                ("code", code_match),
                ("labelRo", label_match),
                ("category", category_match),
                ("urgency", urgency_match),
                ("primaryDepartments", primary_match),
            )
            if field_match is None
        ]
        if missing:
            raise TaxonomyParseError(
                f"IncidentType entry #{index + 1} is missing: {', '.join(missing)} "
                "(keep the argument names from the contract header)"
            )
        parsed.append(
            {
                "code": code_match.group(1),
                "labelRo": label_match.group(1),
                "categoryMember": category_match.group(1),
                "urgencyMember": urgency_match.group(1),
                "primaryMembers": re.findall(
                    r"Department\.(\w+)", primary_match.group(1)
                ),
                "standbyMembers": re.findall(
                    r"Department\.(\w+)",
                    standby_match.group(1) if standby_match else "",
                ),
            }
        )
    return parsed


def build_catalog(source: str) -> dict[str, Any]:
    categories = parse_enum(source, "IncidentCategory")
    labels = dict(
        (match.group(2), match.group(3))
        for match in re.finditer(
            r"^\s*(\w+)\('([^']+)',\s*'([^']*)'\)",
            parse_enum_body(source, "IncidentCategory"),
            re.M,
        )
    )
    urgency_members = parse_enum(source, "Urgency")
    department_members = parse_enum(source, "Department")
    types = parse_types(source)

    schema_version_match = re.search(r"static const int schemaVersion = (\d+);", source)
    expected_count_match = re.search(r"static const int expectedCount = (\d+);", source)
    schema_version = int(schema_version_match.group(1)) if schema_version_match else 1
    expected_count = int(expected_count_match.group(1)) if expected_count_match else 15

    problems: list[str] = []
    if len(types) != expected_count:
        problems.append(f"expected {expected_count} types, parsed {len(types)}")
    if set(categories.values()) != EXPECTED_CATEGORIES:
        problems.append(
            f"categories {sorted(categories.values())} != {sorted(EXPECTED_CATEGORIES)}"
        )
    if set(urgency_members.values()) != EXPECTED_URGENCIES:
        problems.append(
            f"urgency values {sorted(urgency_members.values())} != {sorted(EXPECTED_URGENCIES)}"
        )

    seen_codes: set[str] = set()
    out_types: list[dict[str, Any]] = []
    for parsed_type in types:
        code = parsed_type["code"]
        if code in seen_codes:
            problems.append(f"duplicate code {code}")
        seen_codes.add(code)
        if code != code.upper():
            problems.append(f"{code}: code must be UPPERCASE")
        if not parsed_type["labelRo"].strip():
            problems.append(f"{code}: empty labelRo")
        if parsed_type["categoryMember"] not in categories:
            problems.append(
                f"{code}: unknown category member {parsed_type['categoryMember']!r}"
            )
        if parsed_type["urgencyMember"] not in urgency_members:
            problems.append(
                f"{code}: unknown urgency member {parsed_type['urgencyMember']!r}"
            )
        if not parsed_type["primaryMembers"]:
            problems.append(f"{code}: no primary departments")
        for member in parsed_type["primaryMembers"] + parsed_type["standbyMembers"]:
            if member not in department_members:
                problems.append(f"{code}: unknown department member {member!r}")

        out_types.append(
            {
                "code": code,
                "label_ro": parsed_type["labelRo"],
                "category": categories[parsed_type["categoryMember"]],
                "urgency": urgency_members[parsed_type["urgencyMember"]],
                "primary_departments": [
                    department_members[member]
                    for member in parsed_type["primaryMembers"]
                ],
                "standby_departments": [
                    department_members[member]
                    for member in parsed_type["standbyMembers"]
                ],
            }
        )

    for category in EXPECTED_CATEGORIES:
        if not any(t["category"] == category for t in out_types):
            problems.append(f"category {category!r} has no types")

    if problems:
        raise TaxonomyParseError("invalid taxonomy.dart:\n - " + "\n - ".join(problems))

    return {
        "version": schema_version,
        "generated_from": "lib/core/incidents/taxonomy.dart",
        "categories": [
            {"wire": wire, "label_ro": labels.get(wire, wire)}
            for member, wire in categories.items()
        ],
        "types": out_types,
    }


def parse_enum_body(source: str, name: str) -> str:
    match = re.search(r"enum\s+" + re.escape(name) + r"\s*\{(.*?)\n\}", source, re.S)
    if not match:
        raise TaxonomyParseError(f"could not find `enum {name}`")
    return match.group(1)


def diff_catalog(expected: dict[str, Any], actual: dict[str, Any]) -> list[str]:
    problems: list[str] = []
    if expected.get("version") != actual.get("version"):
        problems.append(
            f"version: dart={expected.get('version')} json={actual.get('version')}"
        )
    if expected.get("categories") != actual.get("categories"):
        problems.append("categories differ")
    expected_types = {t["code"]: t for t in expected.get("types", [])}
    actual_types = {t.get("code"): t for t in actual.get("types", [])}
    for code in sorted(set(expected_types) - set(actual_types)):
        problems.append(f"missing in json: {code}")
    for code in sorted(set(actual_types) - set(expected_types)):
        problems.append(f"stale in json: {code}")
    for code in sorted(set(expected_types) & set(actual_types)):
        for field in (
            "label_ro",
            "category",
            "urgency",
            "primary_departments",
            "standby_departments",
        ):
            if expected_types[code].get(field) != actual_types[code].get(field):
                problems.append(
                    f"{code}.{field}: dart={expected_types[code].get(field)!r} "
                    f"json={actual_types[code].get(field)!r}"
                )
    return problems


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument(
        "--write", action="store_true", help="write backend/taxonomy.json"
    )
    parser.add_argument("--quiet", action="store_true")
    args = parser.parse_args()

    try:
        source = _read(DART_PATH)
        catalog = build_catalog(source)
    except (FileNotFoundError, TaxonomyParseError) as exc:
        print(f"[taxonomy] ERROR: {exc}", file=sys.stderr)
        return 2

    text = json.dumps(catalog, indent=2, ensure_ascii=False) + "\n"
    counts = {
        category: sum(1 for t in catalog["types"] if t["category"] == category)
        for category in sorted(EXPECTED_CATEGORIES)
    }

    if args.write:
        JSON_PATH.parent.mkdir(parents=True, exist_ok=True)
        JSON_PATH.write_text(text, encoding="utf-8", newline="\n")
        print(
            f"[taxonomy] wrote {JSON_PATH.relative_to(REPO_ROOT)} · "
            f"v{catalog['version']} · {len(catalog['types'])} types · {counts}"
        )
        return 0

    if not JSON_PATH.exists():
        print(
            f"[taxonomy] {JSON_PATH.relative_to(REPO_ROOT)} missing — "
            "run: python scripts/sync_taxonomy.py --write",
            file=sys.stderr,
        )
        return 2

    actual = json.loads(JSON_PATH.read_text(encoding="utf-8"))
    problems = diff_catalog(catalog, actual)
    if problems:
        print(
            "[taxonomy] DRIFT between taxonomy.dart and backend/taxonomy.json:",
            file=sys.stderr,
        )
        for problem in problems:
            print(f"  - {problem}", file=sys.stderr)
        print(
            "  Fix: python scripts/sync_taxonomy.py --write "
            "(or dart run tool/emit_taxonomy.dart --write)",
            file=sys.stderr,
        )
        return 1

    if not args.quiet:
        print(
            f"[taxonomy] OK · v{catalog['version']} · {len(catalog['types'])} types · {counts}"
        )
    return 0


if __name__ == "__main__":
    sys.exit(main())
