"""Seeds demo incidents so the dispatcher/crew screens have data immediately.

Run AFTER the backend is up (from the repo root):

    python backend/seed_demo.py                      # 3 reports
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
        "name": "voice · fire/smoke",
        "body": {
            "source": "voice",
            "transcript": (
                "Este fum dens lângă poarta 12, în terminalul 1, pare să iasă "
                "de sub un scaun din zona de așteptare. Nu se vede flacără, "
                "dar miroase înțepător."
            ),
            "reporter_id": "seed-reporter-1",
            "reporter_name": "Andrei P.",
            "location": {"terminal": "T1", "zone": "Poarta 12", "note": "zona de așteptare"},
            "use_ai": True,
        },
    },
    {
        "name": "voice · unattended bag",
        "body": {
            "source": "voice",
            "transcript": (
                "Am găsit un bagaj fără proprietar lângă banda de bagaje 3, "
                "nimeni nu știe al cui este. A stat acolo mai mult de 20 de minute."
            ),
            "reporter_id": "seed-reporter-2",
            "reporter_name": "Ioana M.",
            "location": {"terminal": "T2", "zone": "Banda bagaje 3"},
            "use_ai": True,
        },
    },
    {
        "name": "menu · belt fault (manual)",
        "body": {
            "source": "menu",
            "transcript": "Defecțiune bandă transportoare bagaje",
            "reporter_id": "seed-reporter-3",
            "reporter_name": "Mihai D.",
            "location": {"terminal": "T2", "zone": "Check-in zona B"},
            "hint_code": "MT-BELT",
            "use_ai": False,
        },
    },
    {
        "name": "voice · spill in terminal (janitor)",
        "body": {
            "source": "voice",
            "transcript": (
                "S-a vărsat un lichid pe jos lângă poarta 3, în terminalul 1, "
                "e alunecos și lumea trece pe lângă."
            ),
            "reporter_id": "seed-reporter-5",
            "reporter_name": "Andrei P.",
            "location": {"terminal": "T1", "zone": "Poarta 3"},
            "use_ai": True,
        },
    },
    {
        "name": "voice · forced override (demo)",
        "body": {
            "source": "voice",
            "transcript": (
                "Ceva nu este în regulă pe holul de lângă poarta 7, nu îmi dau "
                "seama exact ce, dar pare o problemă de securitate."
            ),
            "reporter_id": "seed-reporter-4",
            "reporter_name": "Elena V.",
            "location": {"terminal": "T1", "zone": "Poarta 7"},
            "use_ai": True,
            # Forces the 5-second dispatcher override path deterministically,
            # so the demo never depends on the model's confidence.
            "force_override": True,
        },
    },
)


def _post(base: str, token: str, path: str, payload: dict[str, Any], timeout: float) -> dict[str, Any]:
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
            print(f"  reset skipped: HTTP {exc.code} {exc.read().decode(errors='replace')}")
        except urllib.error.URLError as exc:
            print(f"  cannot reach backend: {exc.reason}")
            return 1

    for scenario in SCENARIOS:
        try:
            result = _post(args.base, args.token, "/api/reports", scenario["body"], args.timeout)
        except urllib.error.HTTPError as exc:
            body = exc.read().decode(errors="replace")
            print(f"  FAILED {scenario['name']}: HTTP {exc.code} {body}")
            return 1
        except urllib.error.URLError as exc:
            print(f"  FAILED {scenario['name']}: cannot reach {args.base} ({exc.reason})")
            return 1
        ticket = result["ticket"]
        print(
            f"  {scenario['name']:<30} -> {ticket['incident_code']:<10} "
            f"{ticket['status']:<18} conf={ticket['confidence']:.2f} "
            f"ai={ticket['ai_source']:<8} id={ticket['id'][:8]}"
        )

    print("\nDone. Open the dispatcher screen: the last ticket should be in the")
    print("5-second override window (auto-dispatches if nobody acts).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
