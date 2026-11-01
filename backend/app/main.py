"""FastAPI entrypoint: REST + WSS on one TLS listener.

    backend> .\\run.ps1                 # https://0.0.0.0:8443 + wss://.../ws
    backend> .\\run_insecure.ps1        # http://0.0.0.0:8080 (demo emergency)

Auth: every /api/* request and the /ws socket need
`Authorization: Bearer <API_TOKEN>` (default demo-token). `/`, `/healthz` and
`/ca.crt` are public on purpose (phone certificate checks).
"""

from __future__ import annotations

import asyncio
import base64
import binascii
import importlib.util
import json
import logging
from contextlib import asynccontextmanager
from dataclasses import replace
from pathlib import Path

from fastapi import (
    APIRouter,
    Depends,
    FastAPI,
    Header,
    HTTPException,
    Query,
    WebSocket,
    WebSocketDisconnect,
)
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse, HTMLResponse

from . import schemas
from . import occurrences as occurrence_catalog
from .ai import (
    KEYWORD_RULES,
    OllamaClient,
    analyze_conversation,
    analyze_report,
    extract_location,
)
from .config import BASE_DIR, settings
from .domain import load_domain_config
from .stats import PERIODS as STATS_PERIODS, build_stats
from .stt import (
    merge_corrected_transcript,
    stt_available,
    warmup_stt,
    stt_error,
    transcribe_audio,
)
from .store import Conflict, Hub, NotFound, TicketStore, utc_now
from .taxonomy import get_taxonomy

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)-7s %(name)s: %(message)s",
)
logger = logging.getLogger("airport.api")

CERTS_DIR = BASE_DIR / "certs"

# Multipart support is optional (python-multipart): the Flutter app uses the
# JSON/base64 variant, the upload route is a convenience for curl/automation.
_MULTIPART_AVAILABLE = importlib.util.find_spec("multipart") is not None

taxonomy = get_taxonomy()
hub = Hub()
domain = load_domain_config()
store = TicketStore(taxonomy, hub, settings, domain=domain)
ollama = OllamaClient(
    settings.ollama_url, settings.ollama_model, settings.ollama_timeout_seconds
)


# ── auth ──────────────────────────────────────────────────────────────────────
def _extract_token(authorization: str | None, token: str | None) -> str | None:
    if authorization and authorization.lower().startswith("bearer "):
        return authorization[7:].strip()
    return token


async def require_token(
    authorization: str | None = Header(default=None),
    token: str | None = Query(default=None),
) -> None:
    expected = settings.api_token
    if not expected:
        return
    if _extract_token(authorization, token) != expected:
        raise HTTPException(
            status_code=401,
            detail="Invalid or missing API token. Send 'Authorization: Bearer <API_TOKEN>'.",
        )


# ── heartbeat ─────────────────────────────────────────────────────────────────
async def _heartbeat_loop() -> None:
    while True:
        await asyncio.sleep(20)
        try:
            await hub.broadcast("ping", {})
        except asyncio.CancelledError:
            raise
        except Exception:  # noqa: BLE001 - heartbeat must never kill the app
            logger.exception("Heartbeat broadcast failed")


@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info(
        "Taxonomy v%s · %s incident types · generated_from=%s",
        taxonomy.version,
        len(taxonomy.types),
        taxonomy.generated_from or "?",
    )
    unknown_codes = [
        code for code, _keywords in KEYWORD_RULES if taxonomy.by_code(code) is None
    ]
    if unknown_codes:
        logger.warning(
            "Fallback classifier references codes missing from the taxonomy: %s "
            "(update KEYWORD_RULES in app/ai.py)",
            ", ".join(unknown_codes),
        )

    catalog_problems = occurrence_catalog.validate_catalog(
        {item.code for item in taxonomy.types}
    )
    if catalog_problems:
        raise RuntimeError(
            "Invalid occurrence catalog: " + "; ".join(catalog_problems[:10])
        )
    logger.info(
        "Occurrence catalog v%s · %s source-backed incidents",
        occurrence_catalog.catalog()["version"],
        len(occurrence_catalog.all_occurrences()),
    )
    logger.info(
        "OLLAMA_URL=%s OLLAMA_MODEL=%s CONFIDENCE_THRESHOLD=%.2f RESOLVE_QUORUM=%s",
        settings.ollama_url,
        settings.ollama_model,
        settings.confidence_threshold,
        settings.resolve_quorum,
    )

    warmup_task = asyncio.create_task(ollama.warmup(), name="ollama-warmup")
    stt_warmup_task = asyncio.create_task(
        asyncio.to_thread(warmup_stt), name="stt-warmup"
    )
    heartbeat_task = asyncio.create_task(_heartbeat_loop(), name="ws-heartbeat")
    try:
        yield
    finally:
        for task in (warmup_task, stt_warmup_task, heartbeat_task):
            task.cancel()
        await asyncio.gather(
            warmup_task, stt_warmup_task, heartbeat_task, return_exceptions=True
        )
        await ollama.close()


app = FastAPI(
    title="Wingman API",
    version="0.1.0",
    lifespan=lifespan,
    description=(
        "Closed-taxonomy incident reporting: voice/menu report → Ollama "
        "classification → WSS broadcast → dispatcher override → crew vote."
    ),
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

api = APIRouter(prefix="/api", dependencies=[Depends(require_token)])


# ── helpers ───────────────────────────────────────────────────────────────────
def _to_http(exc: Exception) -> HTTPException:
    if isinstance(exc, NotFound):
        return HTTPException(status_code=404, detail=str(exc))
    if isinstance(exc, Conflict):
        return HTTPException(status_code=409, detail=str(exc))
    if isinstance(exc, KeyError):
        detail = exc.args[0] if exc.args else str(exc)
        return HTTPException(status_code=400, detail=str(detail))
    if isinstance(exc, ValueError):
        return HTTPException(status_code=400, detail=str(exc))
    logger.exception("Unhandled error", exc_info=exc)
    return HTTPException(status_code=500, detail="Internal server error")


def _location_label(location: dict) -> str:
    parts = [
        str(location.get("terminal") or "").strip(),
        str(location.get("zone") or "").strip(),
        str(location.get("note") or "").strip(),
    ]
    label = " · ".join(part for part in parts if part)
    return label or "locație nespecificată"


@app.get("/api/domain")
async def get_domain(_: None = Depends(require_token)) -> dict:
    """Active application profile shared with the Flutter DomainConfig."""
    return domain.to_public_dict()


@app.get("/api/accounts/{crew_id}/rewards")
async def account_rewards(
    crew_id: str,
    _: None = Depends(require_token),
) -> dict:
    """Reward ledger computed by the domain RewardPolicy (same rules as app)."""
    tickets = await store.list_tickets()
    return domain.reward_ledger(crew_id, tickets)


# ── public endpoints (phone certificate checks) ───────────────────────────────
@app.get("/healthz", include_in_schema=False)
async def healthz() -> dict:
    return {
        "status": "ok",
        "service": "wingman-api",
        "time": utc_now(),
        "taxonomy_version": taxonomy.version,
        "domain": domain.id,
        "quorum_strategy": domain.quorum.strategy,
        "reward_strategy": domain.rewards.strategy,
        "tickets": store.count,
        "database": "sqlite",
        "database_rows": store.database_rows,
        "database_path": store.database_path,
        "ws_clients": hub.count,
    }


@app.get("/", response_class=HTMLResponse, include_in_schema=False)
async def status_page() -> str:
    return f"""<!doctype html>
<html lang="ro"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>{domain.app_name} API</title></head>
<body style="font-family:system-ui;padding:24px;line-height:1.5">
<h1>{domain.app_name} API pornit ✔</h1>
<p>Domeniu <b>{domain.id}</b> · taxonomia v{taxonomy.version} · {len(taxonomy.types)} tipuri de incident · {store.count} tichete live.</p>
<p>Dacă vezi această pagină în Safari/Chrome <b>fără avertisment TLS</b>, profilul CA este instalat corect pe acest device.</p>
<p><a href="/ca.crt">descarcă certificatul CA</a> · <a href="/healthz">/healthz</a> · <a href="/docs">/docs</a></p>
</body></html>"""


@app.get("/ca.crt", include_in_schema=False)
async def download_ca():
    """Convenience for phone setup: download the CA over the LAN."""
    path: Path = CERTS_DIR / "ca.crt"
    if not path.exists():
        raise HTTPException(
            status_code=404,
            detail="certs/ca.crt missing — run scripts/gen_certs.ps1 on the laptop",
        )
    return FileResponse(
        path,
        media_type="application/x-x509-ca-cert",
        filename="ca.crt",
    )


# ── REST ──────────────────────────────────────────────────────────────────────
@api.get("/stats")
async def stats(
    period: str = "week",
    _: None = Depends(require_token),
) -> dict:
    """Admin statistics: top problems, counts and frequency by period."""
    if period not in STATS_PERIODS:
        raise HTTPException(
            status_code=400,
            detail="period must be one of: " + ", ".join(STATS_PERIODS),
        )
    tickets = await store.list_tickets()
    return build_stats(tickets, period=period)


@api.get("/health")
async def health() -> dict:
    return {
        "status": "ok",
        "service": "wingman-api",
        "time": utc_now(),
        "taxonomy_version": taxonomy.version,
        "incident_types": len(taxonomy.types),
        "tickets": store.count,
        "ws_clients": hub.count,
        "confidence_threshold": settings.confidence_threshold,
        "domain": domain.id,
        "resolve_quorum": domain.quorum.required_for(1),
        "resolve_quorum_by": domain.quorum.strategy,
        "rewards": {
            "strategy": domain.rewards.strategy,
            "attendedPoints": domain.rewards.attended_points,
            "resolvedBonus": domain.rewards.resolved_bonus,
            "pointsLabel": domain.rewards.points_label,
        },
        "ollama": {
            "url": settings.ollama_url,
            "model": settings.ollama_model,
            "reachable": ollama.reachable,
            "last_ok": ollama.last_ok,
            "last_error": ollama.last_error,
            "last_latency_ms": ollama.last_latency_ms,
            "available_models": ollama.available_models,
        },
        "stt": {
            "provider": "faster-whisper",
            "model": settings.whisper_model,
            "device": settings.whisper_device,
            "available": stt_available(),
            "error": stt_error(),
            "max_audio_bytes": settings.max_audio_bytes,
        },
    }


@api.get("/taxonomy")
async def taxonomy_endpoint() -> dict:
    return taxonomy.as_dict()


@api.get("/occurrences")
async def occurrences_endpoint(
    code: str | None = None,
    category: str | None = None,
) -> dict:
    """Source-backed catalog of possible airport incidents (EU 2015/1018 + ASRS)."""
    data = occurrence_catalog.catalog()
    items = occurrence_catalog.find_occurrences(code=code, category=category)
    return {
        "version": data["version"],
        "sources": data["sources"],
        "categories": data["categories"],
        "count": len(items),
        "occurrences": items,
    }


@api.get("/occurrences/{occurrence_id}")
async def occurrence_endpoint(occurrence_id: str) -> dict:
    item = occurrence_catalog.get_occurrence(occurrence_id)
    if item is None:
        raise HTTPException(status_code=404, detail="Unknown occurrence id")
    return {"occurrence": item}


@api.post("/analyze")
async def analyze(body: schemas.AnalyzeIn) -> dict:
    """Conversational turn for the reporter flow (no ticket created).

    Returns exactly what the app needs to keep the conversation going:
    `fields` (extracted so far), `missing` (slots still needed), `question`
    (next thing to display + speak, or null when ready to submit),
    `clarifications_asked`, `max_clarifications`, `ready` and the current
    `classification` snapshot. After MAX_CLARIFICATIONS the server stops
    asking and caps confidence at 0.40 so the ticket goes to the dispatcher.
    """
    location = body.location.model_dump()
    try:
        state = await analyze_conversation(
            ollama,
            taxonomy,
            body.transcript,
            _location_label(location),
            body.hint_code,
            body.known_incident_code,
            body.clarifications_asked,
        )
    except (ValueError, KeyError) as exc:
        raise _to_http(exc) from exc
    payload = state.to_wire()
    payload["taxonomy_version"] = taxonomy.version
    return payload


@api.post("/transcribe")
async def transcribe(body: schemas.TranscribeIn) -> dict:
    """Audio -> text for the voice reporter flow (local faster-whisper).

    The app records a clip, posts it here, then sends the returned text to
    `/api/analyze` or `/api/reports` exactly as if the user had typed it.
    Failure modes are explicit: 400 for bad/oversized audio, 503 when the
    Whisper package or model is not installed (menus keep working).
    """
    try:
        audio = base64.b64decode(body.audio_base64, validate=True)
    except (binascii.Error, ValueError) as exc:
        raise HTTPException(
            status_code=400, detail="audio_base64 is not valid base64"
        ) from exc
    language = body.language if body.language not in (None, "", "auto") else None
    try:
        result = await transcribe_audio(audio, language, body.mime_type)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except RuntimeError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    logger.info(
        "Transcribed %d audio bytes -> %d chars (%s, %d ms)",
        len(audio),
        len(result.text),
        result.language or "?",
        result.latency_ms,
    )
    # LLM preprocessing: fix only obvious ASR errors before the reporter sees/
    # classifies the sentence. Word probabilities are re-aligned so LLM-changed
    # words stay visibly editable.
    if settings.transcript_correction and result.text.strip():
        corrected = await ollama.correct_transcript(
            result.text,
            result.language,
            timeout=settings.transcript_correction_timeout,
        )
        if corrected:
            merged_text, merged_words = merge_corrected_transcript(
                result.text,
                result.words,
                corrected,
            )
            if merged_text != result.text:
                result = replace(
                    result,
                    text=merged_text,
                    raw_text=result.text,
                    corrected=True,
                    words=merged_words,
                )
                logger.info("Transcript corrected with LLM (safe merge)")
    return result.to_wire()


if _MULTIPART_AVAILABLE:
    from fastapi import File, Form, UploadFile  # noqa: E402  (optional route)

    @api.post("/transcribe/upload")
    async def transcribe_upload(
        file: UploadFile = File(...),
        language: str | None = Form(default=None),
    ) -> dict:
        """Multipart variant of `/api/transcribe` (curl, scripts, other clients)."""
        raw = await file.read()
        language_value = language if language not in (None, "", "auto") else None
        try:
            result = await transcribe_audio(
                raw, language_value, file.content_type or "audio/mp4"
            )
        except ValueError as exc:
            raise HTTPException(status_code=400, detail=str(exc)) from exc
        except RuntimeError as exc:
            raise HTTPException(status_code=503, detail=str(exc)) from exc
        return result.to_wire()


@api.post("/reports", status_code=201)
async def create_report(report: schemas.ReportIn) -> dict:
    location = report.location.model_dump()
    # Free-text reports (PC dashboard, typed mobile path) may not have a zone
    # field filled — pull the zone out of the sentence instead (Craiova zones,
    # gates, entrances, parking, etc.).
    if not any(
        str(location.get(key) or "").strip() for key in ("terminal", "zone", "note")
    ):
        extracted = extract_location(report.transcript)
        if extracted:
            location["zone"] = extracted
    try:
        classification = await analyze_report(
            ollama,
            taxonomy,
            report.transcript,
            _location_label(location),
            report.hint_code,
            report.use_ai,
        )
        existing = await store.find_duplicate(
            incident_code=classification.incident_code,
            transcript=report.transcript,
            location=location,
        )
        if existing is not None:
            logger.info(
                "Duplicate report merged into existing ticket %s (%s)",
                existing["id"],
                existing["incident_code"],
            )
            existing = await store.attach_media(
                existing["id"],
                photo_base64=report.photo_base64,
                location=location,
                reporter_id=report.reporter_id or "anon",
                reporter_name=report.reporter_name or "Anonim",
            )
            return {
                "ticket": existing,
                "duplicate": True,
                "taxonomy_version": taxonomy.version,
            }

        ticket = await store.create(
            source=report.source,
            transcript=report.transcript.strip(),
            reporter_id=report.reporter_id or "anon",
            reporter_name=report.reporter_name or "Anonim",
            location=location,
            classification=classification,
            photo_base64=report.photo_base64,
            quorum_override=report.quorum_override,
        )
    except (ValueError, KeyError) as exc:
        raise _to_http(exc) from exc
    logger.info(
        "Report → %s (%s, confidence %.2f, %s) by %s",
        ticket["incident_code"],
        ticket["status"],
        ticket["confidence"],
        ticket["ai_source"],
        ticket["reporter_name"],
    )
    return {"ticket": ticket}


@api.get("/tickets")
async def list_tickets(status: str | None = Query(default=None)) -> dict:
    try:
        tickets = await store.list_tickets(status)
    except ValueError as exc:
        raise _to_http(exc) from exc
    return {"tickets": tickets, "count": len(tickets)}


@api.post("/tickets/clear-history")
async def clear_ticket_history() -> dict:
    """Admin-only action: permanently remove resolved/denied tickets."""
    cleared = await store.clear_history()
    return {"cleared": cleared}


@api.get("/tickets/{ticket_id}")
async def get_ticket(ticket_id: str) -> dict:
    try:
        ticket = await store.get(ticket_id)
    except NotFound as exc:
        raise _to_http(exc) from exc
    return {"ticket": ticket}


@api.patch("/tickets/{ticket_id}")
async def edit_ticket(ticket_id: str, body: schemas.TicketEditIn) -> dict:
    """Reporter can add a photo / fix the transcript after submitting."""
    try:
        ticket = await store.edit_content(
            ticket_id,
            body.reporter_id,
            body.transcript,
            body.photo_base64,
        )
    except (NotFound, Conflict) as exc:
        raise _to_http(exc) from exc
    return {"ticket": ticket}


@api.post("/tickets/{ticket_id}/confirm")
async def confirm_ticket(
    ticket_id: str,
    body: schemas.DispatcherActionIn | None = None,
) -> dict:
    action = body or schemas.DispatcherActionIn()
    try:
        ticket = await store.confirm(
            ticket_id, action.dispatcher_id, action.dispatcher_name
        )
    except (NotFound, Conflict) as exc:
        raise _to_http(exc) from exc
    return {"ticket": ticket}


@api.post("/tickets/{ticket_id}/deny")
async def deny_ticket(
    ticket_id: str,
    body: schemas.DenyIn | None = None,
) -> dict:
    action = body or schemas.DenyIn()
    try:
        ticket = await store.deny(
            ticket_id,
            action.reason,
            action.dispatcher_id,
            action.dispatcher_name,
        )
    except (NotFound, Conflict) as exc:
        raise _to_http(exc) from exc
    return {"ticket": ticket}


@api.post("/tickets/{ticket_id}/resolution-confirm")
async def confirm_resolution(
    ticket_id: str,
    body: schemas.ResolutionConfirmIn | None = None,
) -> dict:
    """Final admin check for high/critical tickets after crew quorum."""
    action = body or schemas.ResolutionConfirmIn()
    try:
        ticket = await store.confirm_resolution(
            ticket_id,
            action.dispatcher_id,
            action.dispatcher_name,
        )
    except (NotFound, Conflict) as exc:
        raise _to_http(exc) from exc
    return {"ticket": ticket}


@api.post("/tickets/{ticket_id}/override")
async def override_ticket(
    ticket_id: str,
    body: schemas.OverrideIn,
) -> dict:
    try:
        ticket = await store.override(
            ticket_id,
            incident_code=body.incident_code,
            urgency=body.urgency,
            reason=body.reason,
            dispatcher_id=body.dispatcher_id,
            dispatcher_name=body.dispatcher_name,
        )
    except (NotFound, Conflict, KeyError) as exc:
        raise _to_http(exc) from exc
    return {"ticket": ticket}


@api.post("/tickets/{ticket_id}/join")
async def join_ticket(ticket_id: str, body: schemas.JoinIn) -> dict:
    try:
        ticket = await store.join(
            ticket_id, body.crew_id, body.department, body.crew_name
        )
    except (NotFound, Conflict) as exc:
        raise _to_http(exc) from exc
    return {"ticket": ticket}


@api.post("/tickets/{ticket_id}/leave")
async def leave_ticket(ticket_id: str, body: schemas.JoinIn) -> dict:
    """Retract an accidental join; also removes the crew member's vote."""
    try:
        ticket = await store.leave(ticket_id, body.crew_id)
    except (NotFound, Conflict) as exc:
        raise _to_http(exc) from exc
    return {"ticket": ticket}


@api.post("/tickets/{ticket_id}/vote")
async def vote_ticket(ticket_id: str, body: schemas.VoteIn) -> dict:
    try:
        ticket = await store.vote(ticket_id, body.crew_id, body.approve)
    except (NotFound, Conflict) as exc:
        raise _to_http(exc) from exc
    return {"ticket": ticket}


@api.post("/dev/reset")
async def dev_reset() -> dict:
    if not settings.allow_dev_reset:
        raise HTTPException(
            status_code=404, detail="Dev reset disabled (ENABLE_DEV_RESET=0)"
        )
    removed = await store.reset()
    logger.info("Dev reset: cleared %s tickets", removed)
    return {"ok": True, "tickets_cleared": removed}


app.include_router(api)


# ── WSS ───────────────────────────────────────────────────────────────────────
@app.websocket("/ws")
async def websocket_endpoint(
    websocket: WebSocket,
    token: str | None = Query(default=None),
) -> None:
    expected = settings.api_token
    provided = _extract_token(websocket.headers.get("authorization"), token)
    if expected and provided != expected:
        # Reject the handshake before accepting.
        await websocket.close(code=4401, reason="Invalid API token")
        return

    await websocket.accept()
    await hub.register(websocket)
    logger.info("WSS client connected (%s total)", hub.count)
    try:
        await websocket.send_json(
            {
                "type": "hello",
                "ts": utc_now(),
                "data": {
                    "server": "wingman-api",
                    "taxonomy_version": taxonomy.version,
                    "incident_types": len(taxonomy.types),
                },
            }
        )
        while True:
            raw = await websocket.receive_text()
            try:
                payload = json.loads(raw)
            except json.JSONDecodeError:
                continue
            if isinstance(payload, dict) and payload.get("type") == "ping":
                await websocket.send_json({"type": "pong", "ts": utc_now(), "data": {}})
    except WebSocketDisconnect:
        pass
    except RuntimeError:
        # Starlette raises RuntimeError if the client vanished mid-receive.
        pass
    except Exception:  # noqa: BLE001
        logger.exception("WSS loop error")
    finally:
        await hub.unregister(websocket)
        logger.info("WSS client disconnected (%s total)", hub.count)
