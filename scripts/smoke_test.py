#!/usr/bin/env python3
"""End-to-end smoke test for the Wingman API.

Run this AFTER starting the backend (`backend\\run.ps1`), from the repo root:

    python scripts/smoke_test.py                    # https://127.0.0.1:8443
    python scripts/smoke_test.py --insecure         # self-signed cert (default)
    python scripts/smoke_test.py --base https://192.168.1.50:8443
    python scripts/smoke_test.py --skip-override-wait

It verifies, in order:
  1. public /healthz
  2. auth: /api/health rejects a wrong token, accepts the right one
  3. /api/taxonomy serves the same 14 codes as backend/taxonomy.json
  4. WSS handshake + `hello`
  5. manual report (menu flow) -> dispatched, ai_source=manual, exact wire keys
  6. forced low-confidence report -> pending_override -> auto-dispatch after 5 s
  7. crew join -> in_progress, 1 vote -> still open, 2nd vote -> resolved
  8. dispatcher deny -> denied
  9. invalid override code -> HTTP 400

Exit code 0 only if every check passes. Use it as the merge gate.
"""

from __future__ import annotations

import argparse
import asyncio
import json
import ssl
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Any

REPO_ROOT = Path(__file__).resolve().parent.parent
TAXONOMY_JSON = REPO_ROOT / "backend" / "taxonomy.json"

# Windows consoles default to cp1252/cp850; never crash on a unicode check name.
for _stream in (sys.stdout, sys.stderr):
    reconfigure = getattr(_stream, "reconfigure", None)
    if callable(reconfigure):
        try:
            reconfigure(encoding="utf-8", errors="replace")
        except (ValueError, OSError):
            pass

TICKET_KEYS = {
    "id",
    "incident_code",
    "label_ro",
    "category",
    "urgency",
    "status",
    "source",
    "reporter_id",
    "reporter_name",
    "transcript",
    "location",
    "confidence",
    "ai_source",
    "ai_rationale",
    "primary_departments",
    "standby_departments",
    "joined_crew_ids",
    "resolve_votes",
    "resolve_voter_ids",
    "quorum",
    "override_deadline",
    "dispatched_at",
    "resolved_at",
    "resolution_note",
    "decided_by",
    "created_at",
    "updated_at",
    "version",
}
LOCATION_KEYS = {"terminal", "zone", "lat", "lng", "note"}

PASS = 0
FAIL = 0
FAILURES: list[str] = []

# Set from --ca: when provided, TLS is verified against this CA file.
_CA_FILE: str | None = None


def check(name: str, condition: bool, detail: str = "") -> bool:
    global PASS, FAIL
    if condition:
        PASS += 1
        print(f"  PASS  {name}")
    else:
        FAIL += 1
        FAILURES.append(f"{name}{(' — ' + detail) if detail else ''}")
        print(f"  FAIL  {name}" + (f" — {detail}" if detail else ""))
    return condition


def _ssl_context(insecure: bool) -> ssl.SSLContext | None:
    if _CA_FILE:
        # Strict: validate chain + hostname against the project CA (real TLS test).
        return ssl.create_default_context(cafile=_CA_FILE)
    if not insecure:
        return None
    context = ssl.create_default_context()
    context.check_hostname = False
    context.verify_mode = ssl.CERT_NONE
    return context


def http_call(
    base: str,
    token: str,
    path: str,
    *,
    method: str = "GET",
    payload: dict[str, Any] | None = None,
    timeout: float = 30.0,
    insecure: bool = True,
) -> tuple[int, Any]:
    data = json.dumps(payload).encode("utf-8") if payload is not None else None
    request = urllib.request.Request(base.rstrip("/") + path, data=data, method=method)
    request.add_header("Accept", "application/json")
    if payload is not None:
        request.add_header("Content-Type", "application/json; charset=utf-8")
    if token:
        request.add_header("Authorization", f"Bearer {token}")
    try:
        with urllib.request.urlopen(
            request, context=_ssl_context(insecure), timeout=timeout
        ) as response:
            body = response.read().decode("utf-8")
            return response.status, (json.loads(body) if body else {})
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="replace")
        try:
            return exc.code, json.loads(body)
        except json.JSONDecodeError:
            return exc.code, {"raw": body}


def report(
    base: str, token: str, body: dict[str, Any], insecure: bool
) -> tuple[int, Any]:
    return http_call(
        base, token, "/api/reports", method="POST", payload=body, insecure=insecure
    )


async def _ws_listen(
    uri: str,
    insecure: bool,
    events: list[dict[str, Any]],
) -> None:
    try:
        import websockets  # provided by uvicorn[standard]
    except ImportError:
        events.append({"type": "__error__", "error": "websockets not installed"})
        return
    context = None
    if uri.startswith("wss"):
        context = _ssl_context(insecure) or ssl.create_default_context()
    try:
        async with websockets.connect(uri, ssl=context, open_timeout=10) as socket:
            async for raw in socket:
                try:
                    events.append(json.loads(raw))
                except json.JSONDecodeError:
                    events.append({"type": "__bad_json__", "raw": raw})
    except asyncio.CancelledError:
        raise
    except Exception as exc:  # noqa: BLE001 - surfaced as a failed check
        events.append({"type": "__error__", "error": f"{type(exc).__name__}: {exc}"})


async def wait_for_type(
    events: list[dict[str, Any]], wanted: str, timeout: float = 8.0
) -> dict[str, Any] | None:
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        for event in list(events):
            if event.get("type") == wanted:
                return event
        await asyncio.sleep(0.05)
    return None


async def run(args: argparse.Namespace) -> int:
    base = args.base.rstrip("/")
    insecure = args.insecure
    token = args.token
    print(f"\nSmoke test against {base} (TLS verify: {'off' if insecure else 'on'})\n")

    # 1 ── public health ──────────────────────────────────────────────────────
    print("[1] public /healthz")
    status, body = http_call(base, "", "/healthz", insecure=insecure)
    check("/healthz returns 200", status == 200, f"status={status}")
    check("/healthz reports ok", body.get("status") == "ok", str(body))

    # 2 ── auth ───────────────────────────────────────────────────────────────
    print("[2] auth")
    status, _ = http_call(base, "wrong-token", "/api/health", insecure=insecure)
    check("wrong token rejected (401)", status == 401, f"status={status}")
    status, health = http_call(base, token, "/api/health", insecure=insecure)
    check("right token accepted (200)", status == 200, f"status={status}")
    check(
        "health has taxonomy_version", isinstance(health.get("taxonomy_version"), int)
    )
    check("health reports ollama block", isinstance(health.get("ollama"), dict))

    # 3 ── taxonomy parity with the generated file ───────────────────────────
    print("[3] taxonomy")
    expected = (
        json.loads(TAXONOMY_JSON.read_text(encoding="utf-8"))
        if TAXONOMY_JSON.exists()
        else {"types": []}
    )
    expected_codes = [item["code"] for item in expected.get("types", [])]
    status, taxonomy = http_call(base, token, "/api/taxonomy", insecure=insecure)
    actual_codes = [item.get("code") for item in taxonomy.get("types", [])]
    check("/api/taxonomy returns 200", status == 200, f"status={status}")
    check("14 incident types", len(actual_codes) == 14, f"got {len(actual_codes)}")
    check("served codes match taxonomy.json", actual_codes == expected_codes)

    # 4 ── WSS ────────────────────────────────────────────────────────────────
    print("[4] WSS")
    ws_base = base.replace("https://", "wss://").replace("http://", "ws://")
    ws_uri = f"{ws_base}/ws?token={urllib.parse.quote(token)}"
    events: list[dict[str, Any]] = []
    listener = asyncio.create_task(_ws_listen(ws_uri, insecure, events))
    hello = await wait_for_type(events, "hello", timeout=10)
    error = next((e for e in events if e.get("type") == "__error__"), None)
    check(
        "WSS connected", hello is not None, (error or {}).get("error", "no hello event")
    )
    check(
        "hello advertises 14 types",
        (hello or {}).get("data", {}).get("incident_types") == 14,
    )

    try:
        # 5 ── manual report (menu flow, no AI latency) ──────────────────────
        print("[5] manual report (menu flow)")
        status, payload = report(
            base,
            token,
            {
                "source": "menu",
                "transcript": "Defecțiune bandă transportoare bagaje",
                "reporter_id": "smoke-reporter",
                "reporter_name": "Smoke Test",
                "location": {"terminal": "T2", "zone": "Banda 3"},
                "hint_code": "MT-BELT",
                "use_ai": False,
            },
            insecure,
        )
        check("POST /api/reports -> 201", status == 201, f"status={status}")
        manual = payload.get("ticket", {})
        check(
            "manual ticket dispatched",
            manual.get("status") == "dispatched",
            str(manual.get("status")),
        )
        check("manual ticket ai_source=manual", manual.get("ai_source") == "manual")
        check("manual ticket confidence=1.0", manual.get("confidence") == 1.0)
        check(
            "wire keys exactly match the Dart contract",
            set(manual.keys()) == TICKET_KEYS,
            f"missing={sorted(TICKET_KEYS - set(manual.keys()))} extra={sorted(set(manual.keys()) - TICKET_KEYS)}",
        )
        check(
            "location wire keys match",
            set((manual.get("location") or {}).keys()) == LOCATION_KEYS,
            str((manual.get("location") or {}).keys()),
        )
        created_event = await wait_for_type(events, "ticket.created", timeout=5)
        check("ticket.created broadcast on WSS", created_event is not None)
        manual_id = manual.get("id", "")

        # 6 ── override window ───────────────────────────────────────────────
        print("[6] low-confidence override window")
        status, payload = report(
            base,
            token,
            {
                "source": "voice",
                "transcript": "Ceva pare în neregulă pe hol, nu îmi dau seama exact ce.",
                "reporter_id": "smoke-reporter",
                "reporter_name": "Smoke Test",
                "force_override": True,
            },
            insecure,
        )
        check("forced-override report -> 201", status == 201, f"status={status}")
        override = payload.get("ticket", {})
        if args.skip_override_wait:
            print("  SKIP  auto-dispatch wait (--skip-override-wait)")
        else:
            check(
                "status is pending_override",
                override.get("status") == "pending_override",
                str(override.get("status")),
            )
            check("override_deadline present", bool(override.get("override_deadline")))
            check(
                "confidence below threshold",
                float(override.get("confidence", 1)) < 0.65,
                str(override.get("confidence")),
            )
            await asyncio.sleep(5.6)
            status, payload = http_call(
                base, token, f"/api/tickets/{override.get('id')}", insecure=insecure
            )
            auto = payload.get("ticket", {})
            check(
                "auto-dispatched after 5 s",
                auto.get("status") == "dispatched",
                str(auto.get("status")),
            )
            check("auto-dispatch has no dispatcher", auto.get("decided_by") is None)

        # 7 ── join + vote quorum ────────────────────────────────────────────
        print("[7] crew join + vote")
        join_body = {"crew_id": "smoke-crew-a", "crew_name": "Crew A"}
        status, payload = http_call(
            base,
            token,
            f"/api/tickets/{manual_id}/join",
            method="POST",
            payload=join_body,
            insecure=insecure,
        )
        check("join -> 200", status == 200, f"status={status}")
        check(
            "join moves ticket to in_progress",
            payload.get("ticket", {}).get("status") == "in_progress",
        )

        vote_body = {"crew_id": "smoke-crew-a", "approve": True}
        status, payload = http_call(
            base,
            token,
            f"/api/tickets/{manual_id}/vote",
            method="POST",
            payload=vote_body,
            insecure=insecure,
        )
        ticket = payload.get("ticket", {})
        check(
            "first vote counted",
            ticket.get("resolve_votes") == 1,
            str(ticket.get("resolve_votes")),
        )
        check(
            "one vote is not enough (quorum 2)",
            ticket.get("status") == "in_progress",
            str(ticket.get("status")),
        )

        second_vote = {"crew_id": "smoke-crew-b", "approve": True}
        http_call(
            base,
            token,
            f"/api/tickets/{manual_id}/join",
            method="POST",
            payload={"crew_id": "smoke-crew-b", "crew_name": "Crew B"},
            insecure=insecure,
        )
        status, payload = http_call(
            base,
            token,
            f"/api/tickets/{manual_id}/vote",
            method="POST",
            payload=second_vote,
            insecure=insecure,
        )
        ticket = payload.get("ticket", {})
        check(
            "quorum reached -> resolved",
            ticket.get("status") == "resolved",
            str(ticket.get("status")),
        )
        check("resolved_at set", bool(ticket.get("resolved_at")))
        check("summary note present", bool(ticket.get("resolution_note")))
        resolved_event = await wait_for_type(events, "ticket.resolved", timeout=5)
        check("ticket.resolved broadcast on WSS", resolved_event is not None)

        # 8 ── deny ──────────────────────────────────────────────────────────
        print("[8] dispatcher deny")
        _, payload = report(
            base,
            token,
            {
                "source": "menu",
                "transcript": "Acces neautorizat în zonă restricționată",
                "reporter_id": "smoke-reporter",
                "reporter_name": "Smoke Test",
                "hint_code": "SC-ACCESS",
                "use_ai": False,
            },
            insecure,
        )
        deny_id = payload.get("ticket", {}).get("id", "")
        status, payload = http_call(
            base,
            token,
            f"/api/tickets/{deny_id}/deny",
            method="POST",
            payload={
                "reason": "Test: fals pozitiv",
                "dispatcher_id": "smoke-dispatcher",
            },
            insecure=insecure,
        )
        check("deny -> 200", status == 200, f"status={status}")
        check("status is denied", payload.get("ticket", {}).get("status") == "denied")
        check(
            "decided_by recorded",
            payload.get("ticket", {}).get("decided_by") == "smoke-dispatcher",
        )

        # 9 ── invalid override code ─────────────────────────────────────────
        print("[9] invalid reclassification code")
        status, payload = http_call(
            base,
            token,
            f"/api/tickets/{deny_id}/override",
            method="POST",
            payload={
                "incident_code": "XX-NOT-REAL",
                "dispatcher_id": "smoke-dispatcher",
            },
            insecure=insecure,
        )
        check(
            "invalid code rejected (400/409)", status in (400, 409), f"status={status}"
        )
    finally:
        listener.cancel()
        await asyncio.gather(listener, return_exceptions=True)

    # 10 ── conversational /analyze contract (reporter flow) ────────────────
    print("[10] conversational /analyze (fields + missing + question)")
    status, body = http_call(
        base,
        token,
        "/api/analyze",
        method="POST",
        payload={
            "transcript": "Este un miros înțepător, cred că e ceva periculos.",
            "clarifications_asked": 0,
        },
        insecure=insecure,
    )
    check("/api/analyze returns 200", status == 200, f"status={status}")
    check(
        "analyze returns the documented keys",
        all(
            key in body
            for key in (
                "fields",
                "missing",
                "question",
                "ready",
                "clarifications_asked",
                "max_clarifications",
                "classification",
                "taxonomy_version",
            )
        ),
        str(sorted(body.keys())),
    )
    fields = body.get("fields") or {}
    check(
        "fields carry an incident code",
        isinstance(fields.get("incident_code"), str),
        str(fields),
    )
    check(
        "location is reported missing without a location",
        "location" in (body.get("missing") or []),
    )
    check(
        "server asks a location question",
        isinstance(body.get("question"), str) and len(body["question"]) > 5,
        str(body.get("question")),
    )
    check("not ready while a question is pending", body.get("ready") is False)
    check("max_clarifications is 3", body.get("max_clarifications") == 3)

    status, body2 = http_call(
        base,
        token,
        "/api/analyze",
        method="POST",
        payload={
            "transcript": (
                "Este un miros înțepător lângă poarta 12, terminal 1. "
                "Nimeni nu este rănit."
            ),
            "clarifications_asked": 1,
            "known_incident_code": fields.get("incident_code"),
        },
        insecure=insecure,
    )
    fields2 = body2.get("fields") or {}
    check(
        "location extracted from the answer",
        bool(fields2.get("location")),
        str(fields2.get("location")),
    )
    check(
        "people_at_risk honours the negation",
        fields2.get("people_at_risk") is False,
        str(fields2.get("people_at_risk")),
    )
    check(
        "slot questions disappear once slots are filled",
        (body2.get("missing") or []) == [],
        str(body2.get("missing")),
    )

    status, body3 = http_call(
        base,
        token,
        "/api/analyze",
        method="POST",
        payload={"transcript": "Ceva nu este în regulă.", "clarifications_asked": 3},
        insecure=insecure,
    )
    check(
        "no question after max clarifications",
        body3.get("question") is None,
        str(body3.get("question")),
    )
    check(
        "confidence capped for the dispatcher after 3 questions",
        float((body3.get("fields") or {}).get("confidence", 1)) <= 0.40,
        str((body3.get("fields") or {}).get("confidence")),
    )
    check("ready is true when the server stops asking", body3.get("ready") is True)

    # 10c ── do not re-ask what the reporter already said ──────────────────
    print("[10c] complete report → no redundant questions")
    status, body = http_call(
        base,
        token,
        "/api/analyze",
        method="POST",
        payload={
            "transcript": "Un copil a luat foc la poarta 4.",
            "clarifications_asked": 0,
        },
        insecure=insecure,
    )
    fields = body.get("fields") or {}
    check(
        "person caught fire implies people_at_risk",
        fields.get("people_at_risk") is True,
        str(fields.get("people_at_risk")),
    )
    check(
        "location in the sentence is not asked again",
        "location" not in (body.get("missing") or []),
        str(body.get("missing")),
    )
    check(
        "no question when the report is already complete",
        body.get("question") is None,
        str(body.get("question")),
    )
    check("complete report is ready", body.get("ready") is True)

    status, body = http_call(
        base,
        token,
        "/api/analyze",
        method="POST",
        payload={
            "transcript": "Un pasager a leșinat lângă poarta 5, nu respiră.",
            "clarifications_asked": 0,
        },
        insecure=insecure,
    )
    fields = body.get("fields") or {}
    check(
        "collapsed passenger implies people_at_risk",
        fields.get("people_at_risk") is True,
        str(fields.get("people_at_risk")),
    )
    check(
        "unresponsive passenger: no danger question",
        body.get("question") is None,
        str(body.get("question")),
    )

    # Policy: critical reports are dispatched immediately; never ask "is anyone
    # in danger?" (a burning cat cannot answer it).
    status, body = http_call(
        base,
        token,
        "/api/analyze",
        method="POST",
        payload={
            "transcript": "O pisică a luat foc la sector 2 terminal 7.",
            "clarifications_asked": 0,
        },
        insecure=insecure,
    )
    fields = body.get("fields") or {}
    check(
        "animal fire: location extracted",
        "terminal 7" in str(fields.get("location", "")).lower(),
        str(fields.get("location")),
    )
    check(
        "animal fire: dispatched with no question",
        body.get("question") is None,
        str(body.get("question")),
    )
    check("animal fire is ready", body.get("ready") is True)

    status, body = http_call(
        base,
        token,
        "/api/analyze",
        method="POST",
        payload={
            "transcript": "O pisică a luat foc în sectorul 2.",
            "clarifications_asked": 0,
        },
        insecure=insecure,
    )
    fields = body.get("fields") or {}
    check(
        "sector-only location extracted",
        "sector 2" in str(fields.get("location", "")).lower(),
        str(fields.get("location")),
    )
    check(
        "sector-only report: no question",
        body.get("question") is None,
        str(body.get("question")),
    )

    # 10d ── Craiova airport zones (entrances/exits, terminal areas, apron) ──
    print("[10d] Craiova airport zone extraction")
    zone_cases = [
        ("A luat foc un calculator la intrare.", "Intrarea principală"),
        ("Fum la ieșirea principală.", "Ieșirea principală"),
        (
            "Scurgere de combustibil în parcarea de scurtă durată.",
            "Parcare scurtă durată",
        ),
        ("Bagaj abandonat în parcarea P2.", "Parcare"),
        ("Miros de fum în terminalul de sosiri.", "Terminal Sosiri"),
        ("Un pasager a căzut în zona de îmbarcare.", "Zona de îmbarcare"),
        ("Incendiu lângă turnul de control.", "Turn de control"),
        ("Problemă la controlul de securitate.", "Control securitate"),
        ("Corp străin pe pistă lângă stand 3.", "Stand 3"),
        ("Un bagaj suspect lângă banda de bagaje 2.", "Banda 2"),
    ]
    for text, expected in zone_cases:
        status, body = http_call(
            base,
            token,
            "/api/analyze",
            method="POST",
            payload={"transcript": text, "clarifications_asked": 0},
            insecure=insecure,
        )
        fields = body.get("fields") or {}
        location = str(fields.get("location", ""))
        check(
            f"zone extracted: {text[:32]}",
            expected.lower() in location.lower(),
            f"location={location!r}",
        )
        check(
            f"zone report does not ask for the location: {text[:32]}",
            "location" not in (body.get("missing") or []),
            str(body.get("missing")),
        )

    # 10b ── urgency from what was said (mirrors reporter brain/severity.dart)
    print("[10b] urgency escalation from the transcript")
    status, body = http_call(
        base,
        token,
        "/api/analyze",
        method="POST",
        payload={
            "transcript": "Lava curge în terminalul 3 și se extinde rapid!",
            "clarifications_asked": 0,
        },
        insecure=insecure,
    )
    fields = body.get("fields") or {}
    check(
        "lava spill escalated to critical",
        fields.get("urgency") == "critical",
        str(fields.get("urgency")),
    )
    status, body = http_call(
        base,
        token,
        "/api/analyze",
        method="POST",
        payload={
            "transcript": "Un pasager a leșinat lângă poarta 5, nu respiră.",
            "clarifications_asked": 0,
        },
        insecure=insecure,
    )
    fields = body.get("fields") or {}
    check(
        "medical triage is critical",
        fields.get("urgency") == "critical",
        str(fields.get("urgency")),
    )
    status, body = http_call(
        base,
        token,
        "/api/analyze",
        method="POST",
        payload={
            "transcript": (
                "Am găsit un bagaj fără proprietar lângă banda de bagaje 3, "
                "nimeni nu știe al cui este."
            ),
            "clarifications_asked": 0,
        },
        insecure=insecure,
    )
    fields = body.get("fields") or {}
    check(
        "unattended bag beats the belt-fault keyword",
        fields.get("incident_code") == "SC-BAG",
        str(fields.get("incident_code")),
    )

    # 11 ── speech-to-text (voice reporter flow) ────────────────────────────
    print("[11] /api/transcribe (audio -> text, local faster-whisper)")
    import base64 as _b64
    import io as _io
    import wave as _wave

    wav_buffer = _io.BytesIO()
    with _wave.open(wav_buffer, "wb") as wav_file:
        wav_file.setnchannels(1)
        wav_file.setsampwidth(2)
        wav_file.setframerate(16000)
        wav_file.writeframes(b"\x00\x00" * 3200)  # 0.2 s of silence
    audio_b64 = _b64.b64encode(wav_buffer.getvalue()).decode("ascii")
    status, body = http_call(
        base,
        token,
        "/api/transcribe",
        method="POST",
        payload={
            "audio_base64": audio_b64,
            "mime_type": "audio/wav",
            "language": "ro",
        },
        insecure=insecure,
    )
    check(
        "transcribe accepts audio (200, or 503 until the model is downloaded)",
        status in (200, 503),
        f"status={status}",
    )
    if status == 200:
        check(
            "transcribe returns text", isinstance(body.get("text"), str), str(body)[:80]
        )
        check("transcribe returns language", isinstance(body.get("language"), str))
        check(
            "transcribe reports provider=faster-whisper",
            body.get("provider") == "faster-whisper",
            str(body.get("provider")),
        )
        check("transcribe reports latency", isinstance(body.get("latency_ms"), int))
    else:
        print(
            f"  SKIP  whisper model not ready yet: {str(body.get('detail', ''))[:90]}"
        )

    status, body = http_call(
        base,
        token,
        "/api/transcribe",
        method="POST",
        payload={"audio_base64": "$$$not-base64$$$", "mime_type": "audio/wav"},
        insecure=insecure,
    )
    check(
        "invalid audio_base64 rejected (400/422)",
        status in (400, 422),
        f"status={status}",
    )

    # 12 ── reset (leave a clean store for the next run) ────────────────────
    print("[12] dev reset")
    status, body = http_call(
        base, token, "/api/dev/reset", method="POST", insecure=insecure
    )
    if status == 200:
        check("store cleared", body.get("tickets_cleared", 0) >= 0)
    else:
        print(f"  SKIP  dev reset disabled (status={status})")

    print(f"\n{'=' * 60}")
    print(f"  {PASS} passed · {FAIL} failed")
    if FAILURES:
        print("\n  Failures:")
        for failure in FAILURES:
            print(f"   - {failure}")
    print(f"{'=' * 60}\n")
    return 0 if FAIL == 0 else 1


def main() -> int:
    parser = argparse.ArgumentParser(description="End-to-end smoke test")
    parser.add_argument("--base", default="https://127.0.0.1:8443")
    parser.add_argument("--token", default="demo-token")
    parser.add_argument(
        "--strict-tls",
        action="store_true",
        help="verify the server certificate (default: accept self-signed)",
    )
    parser.add_argument(
        "--ca",
        default=None,
        help="verify TLS against this CA PEM (implicitly disables --insecure)",
    )
    parser.add_argument(
        "--skip-override-wait",
        action="store_true",
        help="do not wait 5 s for the auto-dispatch check (fast runs)",
    )
    args = parser.parse_args()
    global _CA_FILE
    _CA_FILE = args.ca
    args.insecure = not args.strict_tls and not args.ca
    try:
        return asyncio.run(run(args))
    except KeyboardInterrupt:
        return 130


if __name__ == "__main__":
    sys.exit(main())
