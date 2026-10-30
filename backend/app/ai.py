"""Ollama classification: prompt, JSON validation, deterministic fallback.

Pipeline for every voice report:

    transcript ──► OllamaClient.classify()  ──► parse_json_object()
                                                   │
                                     resolve code against the CLOSED taxonomy
                                                   │
                                          escalate urgency (never de-escalate)
                                                   │
                                ┌──────────────────┴───────────────────┐
                                │ success: ai_source="ollama"          │
                                │ any failure (timeout/model/garbage): │
                                │ fallback_classify() → ai_source=     │
                                │ "fallback" + low confidence, which   │
                                │ triggers the dispatcher 5 s window   │
                                └──────────────────────────────────────┘

The DEFAULT PROMPT below is what ships. If the team standardised a different
classifier prompt, replace ROLE_PROMPT + RULES_PROMPT only — keep the JSON
schema and the closed-list rule, because the backend validates against them.
"""

from __future__ import annotations

import asyncio
import json
import logging
import re
import time
from dataclasses import dataclass
from typing import Any

import httpx

from .taxonomy import URGENCY_LEVELS, Taxonomy, get_taxonomy

logger = logging.getLogger("airport.ai")

# ─────────────────────────────────────────────────────────────────────────────
# CLASSIFICATION PROMPT
# ─────────────────────────────────────────────────────────────────────────────
ROLE_PROMPT = """Ești clasificatorul de incidente al unui aeroport internațional.
Primești un raport scris sau transcrierea unui mesaj vocal de la un angajat al
aeroportului și trebuie să îl încadrezi în taxonomia ÎNCHISĂ de mai jos."""

RULES_PROMPT = """REGULI OBLIGATORII
1. `incident_code` trebuie să fie EXACT un cod din lista închisă. Nu inventa coduri noi.
2. Dacă raportul nu se potrivește clar, alege codul cel mai apropiat; dacă nimic nu se potrivește, folosește `OP-OTHER`.
3. `urgency` poate fi doar: low, medium, high, critical. Poți RIDICA urgency implicită a codului, niciodată să o cobori.
4. `confidence` este între 0.0 și 1.0: 0.90+ potrivire clară, 0.65-0.89 probabilă, sub 0.65 ambiguă.
5. `rationale`: maximum 12 cuvinte, în română, fără date personale.
6. Răspunde STRICT cu un obiect JSON valid, fără markdown, fără explicații în afara JSON-ului."""

JSON_SCHEMA_PROMPT = """SCHEMA DE RĂSPUNS
{"incident_code": "<cod din listă>", "urgency": "low|medium|high|critical", "confidence": 0.0, "rationale": "<max 12 cuvinte>"}"""

TAXONOMY_HEADER = """TAXONOMIE ÎNCHISĂ (cod | categorie | urgency implicită | etichetă | departamente)
----------------------------------------"""

TAXONOMY_FOOTER = """----------------------------------------
Sfârșitul listei. Orice cod care nu apare mai sus este INVALID."""


def build_system_prompt(taxonomy: Taxonomy) -> str:
    return "\n\n".join(
        [
            ROLE_PROMPT,
            RULES_PROMPT,
            f"{TAXONOMY_HEADER}\n{taxonomy.prompt_catalog()}\n{TAXONOMY_FOOTER}",
            JSON_SCHEMA_PROMPT,
        ]
    )


def build_user_prompt(transcript: str, location_label: str) -> str:
    return (
        f"Locație raportată: {location_label or 'locație nespecificată'}\n"
        f"Raport: {transcript.strip()}\n\n"
        "Clasifică raportul. Răspunde doar cu JSON-ul cerut."
    )


# ─────────────────────────────────────────────────────────────────────────────
# Deterministic fallback (Ollama down / timeout / invalid JSON)
# Order matters: first match wins on equal score. Codes MUST exist in the
# taxonomy (checked once at startup in main.py).
# ─────────────────────────────────────────────────────────────────────────────
KEYWORD_RULES: tuple[tuple[str, tuple[str, ...]], ...] = (
    (
        "SF-FIRE",
        (
            "foc", "fum", "incendiu", "flacăr", "flacar", "arde", "scânte",
            "scante", "fire", "smoke", "burning", "flame",
        ),
    ),
    (
        "SF-FOD",
        (
            "fod", "corp străin", "corp strain", "debris", "obstacol",
            "pistă", "pista", "runway", "taxiway", "platformă", "platforma",
        ),
    ),
    (
        "SF-EQUIP",
        (
            "stingător", "stingator", "hidrant", "extinctor", "extinguisher",
            "fire equipment", "sprinkler",
        ),
    ),
    (
        "SF-SPILL",
        (
            "scurgere", "lichid", "alunec", "ulei", "varsat", "vărsat",
            "spill", "slip", "wet floor",
        ),
    ),
    (
        "SC-BAG",
        (
            "bagaj", "geamantan", "nesupravegheat", "abandonat", "rucsac",
            "unattended", "luggage", "bag",
        ),
    ),
    (
        "SC-ACCESS",
        (
            "acces neautorizat", "neautorizat", "intrus", "efracție",
            "efractie", "zonă restricționată", "zona restrictionata",
            "usa de serviciu", "unauthorized", "secure area", "tailgating",
        ),
    ),
    (
        "SC-ITEM",
        (
            "obiect interzis", "cuțit", "cutit", "armă", "arma", "scaner",
            "raze x", "raze-x", "x-ray", "prohibited", "knife", "weapon",
        ),
    ),
    (
        "SC-BEHAV",
        (
            "agresiv", "altercație", "altercatie", "bătaie", "bataie",
            "suspicios", "comportament", "panică", "panica", "suspect",
            "fighting", "aggressive",
        ),
    ),
    (
        "MT-BELT",
        (
            "bandă", "banda", "transportoare", "carusel", "conveyor",
            "belt", "bagaj blocat",
        ),
    ),
    (
        "MT-ESC",
        (
            "escalator", "scări rulante", "scari rulante", "lift",
            "ascensor", "elevator", "blocat între etaje",
        ),
    ),
    (
        "MT-JBRIDGE",
        (
            "pasarelă", "pasarela", "jet bridge", "jetbridge", "boarding bridge",
            "burduf", "poarta de îmbarcare", "poarta de imbarcare",
        ),
    ),
    (
        "OP-QUEUE",
        (
            "coadă", "coada", "aglomer", "flux", "îmbulzeală", "imbulzeala",
            "security line", "queue",
        ),
    ),
    (
        "OP-IT",
        (
            "it", "sistem", "server", "check-in", "check in", "dcs",
            "rețea", "retea", "network", "calculator", "imprimantă",
            "imprimanta", "printer", "outage", "căzut", "cazut",
        ),
    ),
)


@dataclass(frozen=True)
class Classification:
    incident_code: str
    urgency: str
    confidence: float
    rationale: str
    ai_source: str  # "ollama" | "fallback" | "manual"
    latency_ms: int | None = None

    def to_wire(self) -> dict[str, Any]:
        return {
            "incident_code": self.incident_code,
            "urgency": self.urgency,
            "confidence": self.confidence,
            "rationale": self.rationale,
            "ai_source": self.ai_source,
            "latency_ms": self.latency_ms,
        }


def clamp_confidence(value: Any, default: float = 0.5) -> float:
    try:
        number = float(value)
    except (TypeError, ValueError):
        return default
    return round(min(1.0, max(0.0, number)), 3)


def escalate_urgency(default: str, requested: Any) -> str:
    """The AI may raise urgency for a specific report, never lower it."""
    candidate = str(requested or "").strip().lower()
    if candidate not in URGENCY_LEVELS:
        return default
    if URGENCY_LEVELS.index(candidate) >= URGENCY_LEVELS.index(default):
        return candidate
    return default


def parse_json_object(content: str | None) -> dict[str, Any] | None:
    """Extracts the first JSON object from a model reply, tolerating fences."""
    if not content:
        return None
    text = content.strip()
    text = re.sub(r"^```(?:json)?\s*", "", text)
    text = re.sub(r"\s*```$", "", text).strip()
    start = text.find("{")
    end = text.rfind("}")
    if start < 0 or end <= start:
        return None
    try:
        parsed = json.loads(text[start : end + 1])
    except json.JSONDecodeError:
        return None
    return parsed if isinstance(parsed, dict) else None


def resolve_incident_code(raw: Any, taxonomy: Taxonomy) -> tuple[str, bool]:
    """Maps the model's reply to a taxonomy code.

    Returns (code, fuzzy). `fuzzy=True` means it matched a label/partial
    instead of an exact code, so the caller lowers confidence.
    """
    if not isinstance(raw, str) or not raw.strip():
        raise ValueError("model reply has no incident_code")
    try:
        direct = taxonomy.require(raw)
        return direct.code, False
    except KeyError:
        pass

    lowered = raw.strip().lower()
    for incident_type in taxonomy.types:
        if incident_type.label_ro.lower() == lowered:
            return incident_type.code, True
    for incident_type in taxonomy.types:
        if lowered and (
            lowered in incident_type.label_ro.lower()
            or incident_type.code.lower() in lowered
        ):
            return incident_type.code, True
    raise ValueError(
        f"incident_code {raw!r} is not in the closed taxonomy "
        f"({', '.join(taxonomy.codes())})"
    )


def fallback_classify(
    taxonomy: Taxonomy,
    transcript: str,
    hint_code: str | None = None,
) -> Classification:
    """Deterministic keyword classifier — the demo's safety net."""
    hint = taxonomy.by_code(hint_code)
    if hint is not None:
        return Classification(
            incident_code=hint.code,
            urgency=hint.urgency,
            confidence=0.80,
            rationale="AI indisponibil; se folosește selecția utilizatorului",
            ai_source="manual",
        )

    text = transcript.lower()
    best_code: str | None = None
    best_score = 0
    for code, keywords in KEYWORD_RULES:
        score = 0
        for keyword in keywords:
            if keyword and keyword in text:
                score += 2 if len(keyword) > 6 else 1
        if score > best_score:
            best_code, best_score = code, score

    if best_code is None:
        return Classification(
            incident_code="OP-OTHER",
            urgency="low",
            confidence=0.20,
            rationale="Fără potrivire clară; necesită triaj",
            ai_source="fallback",
        )

    incident_type = taxonomy.require(best_code)
    confidence = min(0.58, 0.30 + 0.04 * best_score)
    return Classification(
        incident_code=incident_type.code,
        urgency=incident_type.urgency,
        confidence=round(confidence, 3),
        rationale=f"Potrivire cuvinte-cheie ({best_score})",
        ai_source="fallback",
    )


class OllamaClient:
    def __init__(self, base_url: str, model: str, timeout_seconds: float) -> None:
        self.base_url = base_url.rstrip("/")
        self.model = model
        self._client = httpx.AsyncClient(
            base_url=self.base_url,
            timeout=httpx.Timeout(timeout_seconds, connect=4.0),
        )
        # Cached health, surfaced by /api/health and the preflight script.
        self.reachable: bool | None = None
        self.last_ok: bool | None = None
        self.last_error: str | None = None
        self.last_latency_ms: int | None = None
        self.available_models: list[str] = []

    async def close(self) -> None:
        await self._client.aclose()

    async def probe(self) -> bool:
        """GET /api/tags: is Ollama up, and is our model pulled?"""
        try:
            response = await self._client.get("/api/tags", timeout=5.0)
            response.raise_for_status()
            payload = response.json()
            models = payload.get("models") or []
            self.available_models = [
                str(item.get("name", "")) for item in models if isinstance(item, dict)
            ]
            self.reachable = True
            if self.available_models and not any(
                name.split(":")[0] == self.model.split(":")[0]
                for name in self.available_models
            ):
                logger.warning(
                    "Ollama is up but model %r is not pulled. Available: %s. "
                    "Run: ollama pull %s",
                    self.model,
                    ", ".join(self.available_models) or "none",
                    self.model,
                )
            return True
        except Exception as exc:  # noqa: BLE001 - health probe must never raise
            self.reachable = False
            self.last_error = f"{type(exc).__name__}: {exc}"
            logger.warning("Ollama probe failed at %s: %s", self.base_url, exc)
            return False

    async def warmup(self) -> None:
        """Loads the model into VRAM before the demo (cold load can be 60 s)."""
        if not await self.probe():
            return
        started = time.monotonic()
        try:
            response = await self._client.post(
                "/api/generate",
                json={
                    "model": self.model,
                    "prompt": "ok",
                    "stream": False,
                    "keep_alive": "30m",
                    "options": {"num_predict": 1},
                },
                timeout=120.0,
            )
            response.raise_for_status()
            self.last_ok = True
            self.last_error = None
            logger.info(
                "Ollama warm-up OK: %s loaded in %.1fs",
                self.model,
                time.monotonic() - started,
            )
        except Exception as exc:  # noqa: BLE001
            self.last_ok = False
            self.last_error = f"{type(exc).__name__}: {exc}"
            logger.warning("Ollama warm-up failed: %s", exc)

    async def classify(self, transcript: str, location_label: str) -> dict[str, Any]:
        taxonomy = get_taxonomy()
        payload = {
            "model": self.model,
            "messages": [
                {"role": "system", "content": build_system_prompt(taxonomy)},
                {
                    "role": "user",
                    "content": build_user_prompt(transcript, location_label),
                },
            ],
            "format": "json",
            "stream": False,
            "keep_alive": "30m",
            "options": {
                "temperature": 0.0,
                "top_p": 0.9,
                "num_predict": 220,
            },
        }
        started = time.monotonic()
        try:
            response = await self._client.post("/api/chat", json=payload)
            response.raise_for_status()
        except Exception as exc:
            self.last_ok = False
            self.reachable = False
            self.last_error = f"{type(exc).__name__}: {exc}"
            raise
        latency_ms = int((time.monotonic() - started) * 1000)
        self.last_ok = True
        self.reachable = True
        self.last_error = None
        self.last_latency_ms = latency_ms
        data = response.json()
        message = data.get("message") or {}
        return {
            "content": message.get("content", ""),
            "latency_ms": latency_ms,
            "model": data.get("model", self.model),
        }


async def analyze_report(
    ollama: OllamaClient,
    taxonomy: Taxonomy,
    transcript: str,
    location_label: str,
    hint_code: str | None = None,
    use_ai: bool = True,
) -> Classification:
    """Classifies one report. Never raises for Ollama problems — degrades."""
    hint = taxonomy.by_code(hint_code)
    if hint_code and hint is None:
        raise ValueError(
            f"hint_code {hint_code!r} is not in the taxonomy. "
            f"Allowed: {', '.join(taxonomy.codes())}"
        )
    if hint is not None and not use_ai:
        return Classification(
            incident_code=hint.code,
            urgency=hint.urgency,
            confidence=1.0,
            rationale="selectat de utilizator din meniu",
            ai_source="manual",
        )

    try:
        raw = await ollama.classify(transcript, location_label)
    except asyncio.CancelledError:
        raise
    except Exception as exc:  # noqa: BLE001 - fallback is the whole point
        logger.warning("Ollama classify failed: %s", exc)
        return fallback_classify(taxonomy, transcript, hint_code)

    try:
        parsed = parse_json_object(raw.get("content"))
        if parsed is None:
            raise ValueError("model reply was not a JSON object")
        code, fuzzy = resolve_incident_code(parsed.get("incident_code"), taxonomy)
        incident_type = taxonomy.require(code)
        confidence = clamp_confidence(parsed.get("confidence"))
        if fuzzy:
            confidence = min(confidence, 0.7)
        if hint is not None and code == hint.code:
            confidence = max(confidence, 0.90)
        rationale = str(parsed.get("rationale") or "").strip()[:200]
        return Classification(
            incident_code=incident_type.code,
            urgency=escalate_urgency(incident_type.urgency, parsed.get("urgency")),
            confidence=confidence,
            rationale=rationale or "clasificare AI",
            ai_source="ollama",
            latency_ms=raw.get("latency_ms"),
        )
    except (ValueError, KeyError) as exc:
        logger.warning("Ollama returned unusable classification: %s", exc)
        return fallback_classify(taxonomy, transcript, hint_code)
