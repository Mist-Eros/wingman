"""Offline contract check: Flutter JSON mapping vs FastAPI wire construction.

Does not need the server or a Dart SDK. Parses:
  • lib/core/models/ticket.dart        → every `json['...']` / `value['...']` read
  • backend/app/store.py              → the ticket dict keys built in `create()`
  • lib/core/models/ticket.dart        → `ReportDraft.toJson()` keys
  • backend/app/schemas.py            → `ReportIn` fields

Run from the repo root (works before every merge):

    python scripts/check_wire_parity.py

Exit 0 = the two sides agree field-for-field; exit 1 = drift (prints the diff).
`scripts/smoke_test.py` additionally proves it against a running server.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
TICKET_DART = REPO_ROOT / "lib" / "core" / "models" / "ticket.dart"
STORE_PY = REPO_ROOT / "backend" / "app" / "store.py"
SCHEMAS_PY = REPO_ROOT / "backend" / "app" / "schemas.py"


def read(path: Path) -> str:
    if not path.exists():
        raise FileNotFoundError(f"{path} not found")
    return path.read_text(encoding="utf-8")


def dart_ticket_keys(source: str) -> tuple[set[str], set[str]]:
    """Keys read by Ticket.fromJson and by IncidentLocation.fromJson."""
    ticket_section = source.split("factory Ticket.fromJson", 1)[-1].split(
        "Ticket copyWith", 1
    )[0]
    ticket_keys = set(re.findall(r"json\['([a-z_]+)'\]", ticket_section))

    location_section = source.split("factory IncidentLocation.fromJson", 1)[-1].split(
        "String toString()", 1
    )[0]
    location_keys = set(re.findall(r"value\['([a-z_]+)'\]", location_section))
    return ticket_keys, location_keys


def dart_report_keys(source: str) -> set[str]:
    section = source.split("class ReportDraft", 1)[-1].split(
        "Map<String, dynamic> toJson()", 1
    )[-1]
    section = section.split("};", 1)[0]
    return set(re.findall(r"'([a-z_]+)'\s*:", section))


def python_ticket_keys(source: str) -> tuple[set[str], set[str]]:
    """Keys of the ticket dict and location dict built in TicketStore.create()."""
    section = source.split("async def create(", 1)[-1].split("async def confirm(", 1)[0]
    ticket_block = section.split("ticket: dict[str, Any] = {", 1)[-1].split(
        "\n        }", 1
    )[0]
    ticket_keys = set(re.findall(r'^\s{12}"([a-z_]+)":', ticket_block, re.M))
    location_block = ticket_block.split('"location": {', 1)[-1].split("},", 1)[0]
    location_keys = set(re.findall(r'"([a-z_]+)":', location_block))
    return ticket_keys, location_keys


def python_report_fields(source: str) -> set[str]:
    section = source.split("class ReportIn(", 1)[-1].split("class AnalyzeIn", 1)[0]
    fields = set(re.findall(r"^\s{4}([a-z_]+):\s", section, re.M))
    return fields


def compare(label: str, dart: set[str], python: set[str]) -> int:
    missing_in_python = sorted(dart - python)
    missing_in_dart = sorted(python - dart)
    if not missing_in_python and not missing_in_dart:
        print(f"  OK    {label}: {len(dart)} fields agree")
        return 0
    print(f"  FAIL  {label}")
    if missing_in_python:
        print(f"        Dart reads but backend never sends: {missing_in_python}")
    if missing_in_dart:
        print(f"        Backend sends but Dart never reads: {missing_in_dart}")
    return 1


def main() -> int:
    parser = argparse.ArgumentParser(description="Dart <-> Python wire parity check")
    parser.add_argument("--quiet", action="store_true")
    args = parser.parse_args()

    try:
        ticket_source = read(TICKET_DART)
        store_source = read(STORE_PY)
        schemas_source = read(SCHEMAS_PY)
    except FileNotFoundError as exc:
        print(f"[wire-parity] ERROR: {exc}", file=sys.stderr)
        return 2

    print("[wire-parity] comparing Dart JSON mapping with the FastAPI wire")
    failures = 0

    dart_ticket, dart_location = dart_ticket_keys(ticket_source)
    py_ticket, py_location = python_ticket_keys(store_source)
    failures += compare("Ticket fields", dart_ticket, py_ticket)
    failures += compare("IncidentLocation fields", dart_location, py_location)

    dart_report = dart_report_keys(ticket_source)
    py_report = python_report_fields(schemas_source)
    failures += compare("ReportDraft/ReportIn fields", dart_report, py_report)

    if failures:
        print(
            "\n[wire-parity] DRIFT. Update both sides and the table in CONTRACTS.md §5,\n"
            "              then re-run this check and scripts/smoke_test.py.",
            file=sys.stderr,
        )
        return 1

    print("[wire-parity] OK - the contracts match")
    return 0


if __name__ == "__main__":
    sys.exit(main())
