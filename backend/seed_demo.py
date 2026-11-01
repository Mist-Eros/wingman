"""Seeds demo incidents so the dispatcher/crew screens have data immediately.

Run AFTER the backend is up (from the repo root):

    python backend/seed_demo.py                      # 5 reports
    python backend/seed_demo.py --reset              # clear store first
    python backend/seed_demo.py --base https://192.168.1.50:8443

TLS is verified only for the local demo path; the script accepts the
self-signed cert (it is a laptop-local helper, not production code).
"""

from __future__ import annotations

import argparse
import json
import ssl
import sys
import urllib.error
import urllib.request
from typing import Any

SCENARIOS: tuple[dict[str, Any], ...] = (
    {
        "name": "green · low · queue/operations",
        "body": {
            "source": "menu",
            "transcript": "Coada de la control este lungă, dar nu e nimic periculos.",
            "reporter_id": "seed-reporter-1",
            "reporter_name": "Andrei P.",
            "location": {"terminal": "T1", "zone": "Control securitate"},
            "hint_code": "OP-OTHER",
            "use_ai": False,
        },
    },
    {
        "name": "yellow · medium · spill",
        "body": {
            "source": "menu",
            "transcript": "S-a vărsat un lichid pe jos lângă poarta 3.",
            "reporter_id": "seed-reporter-2",
            "reporter_name": "Ioana M.",
            "location": {"terminal": "T1", "zone": "Poarta 3"},
            "hint_code": "SF-SPILL",
            "use_ai": False,
        },
    },
    {
        "name": "orange · high · unattended bag",
        "body": {
            "source": "menu",
            "transcript": "Bagaj fără proprietar lângă banda de bagaje 3.",
            "reporter_id": "seed-reporter-3",
            "reporter_name": "Mihai D.",
            "location": {"terminal": "T2", "zone": "Banda bagaje 3"},
            "hint_code": "SC-BAG",
            "use_ai": False,
        },
    },
    {
        "name": "orange · high · belt fault",
        "body": {
            "source": "menu",
            "transcript": "Defecțiune la banda transportoare de bagaje.",
            "reporter_id": "seed-reporter-4",
            "reporter_name": "Elena V.",
            "location": {"terminal": "T2", "zone": "Check-in zona B"},
            "hint_code": "MT-BELT",
            "use_ai": False,
        },
    },
    {
        "name": "red · critical · fire/smoke",
        "body": {
            "source": "menu",
            "transcript": "Fum dens lângă poarta 12, în terminalul 1.",
            "reporter_id": "seed-reporter-5",
            "reporter_name": "Furtuna-Cola Andrei-Alexandru",
            "location": {"terminal": "T1", "zone": "Poarta 12"},
            "hint_code": "SF-FIRE",
            "use_ai": False,
        },
    },
)


def _post(
    base: str, token: str, path: str, payload: dict[str, Any], timeout: float
) -> dict[str, Any]:
    data = json.dumps(payload).encode("utf-8")
    request = urllib.request.Request(
        base.rstrip("/") + path,
        data=data,
        method="POST",
        headers={
            "Content-Type": "application/json; charset=utf-8",
            "Authorization": f"Bearer {token}",
        },
    )
    context = ssl.create_default_context()
    context.check_hostname = False
    context.verify_mode = ssl.CERT_NONE
    with urllib.request.urlopen(request, context=context, timeout=timeout) as response:
        return json.loads(response.read().decode("utf-8"))


def main() -> int:
    parser = argparse.ArgumentParser(description="Seed demo tickets into the backend.")
    parser.add_argument("--base", default="https://127.0.0.1:8443", help="API base URL")
    parser.add_argument("--token", default="demo-token", help="API bearer token")
    parser.add_argument("--reset", action="store_true", help="clear the store first")
    parser.add_argument("--timeout", type=float, default=120.0)
    args = parser.parse_args()

    print(f"-> {args.base}")

    if args.reset:
        try:
            result = _post(args.base, args.token, "/api/dev/reset", {}, 15)
            print(f"  store reset: {result}")
        except urllib.error.HTTPError as exc:
            print(
                f"  reset skipped: HTTP {exc.code} {exc.read().decode(errors='replace')}"
            )
        except urllib.error.URLError as exc:
            print(f"  cannot reach backend: {exc.reason}")
            return 1

    for scenario in SCENARIOS:
        try:
            result = _post(
                args.base, args.token, "/api/reports", scenario["body"], args.timeout
            )
        except urllib.error.HTTPError as exc:
            body = exc.read().decode(errors="replace")
            print(f"  FAILED {scenario['name']}: HTTP {exc.code} {body}")
            return 1
        except urllib.error.URLError as exc:
            print(
                f"  FAILED {scenario['name']}: cannot reach {args.base} ({exc.reason})"
            )
            return 1
        ticket = result["ticket"]
        print(
            f"  {scenario['name']:<30} -> {ticket['incident_code']:<10} "
            f"{ticket['status']:<18} conf={ticket['confidence']:.2f} "
            f"ai={ticket['ai_source']:<8} id={ticket['id'][:8]}"
        )

    print("\nDone. Open the dispatcher screen: the last ticket should be in the")
    print("Every report dispatches immediately; the dispatcher can deny/reclassify.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
