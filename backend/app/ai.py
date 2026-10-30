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
from dataclasses import dataclass, replace
from typing import Any

import httpx

from .config import settings
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
6. Răspunde STRICT cu un obiect JSON valid, fără markdown, fără explicații în afara JSON-ului.
7. GHID DE ÎNCADRARE — dacă textul conține:
   • fum, foc, flacără, incendiu, arde, scânteie → SF-FIRE
   • corp străin, obiect pe pistă/platformă, resturi, FOD → SF-FOD
   • scurgere, lichid, ulei, suprafață alunecoasă → SF-SPILL
   • stingător/hidrant/sprinkler defect, echipament de stingere → SF-EQUIP
   • bagaj nesupravegheat, valiză abandonată, geamantan suspect → SC-BAG
   • acces neautorizat, zonă restricționată, efracție, a intrat fără drept → SC-ACCESS
   • obiect interzis, armă, cuțit, lichid interzis → SC-ITEM
   • persoană suspectă/agresivă/agitată, comportament ciudat, panică → SC-BEHAV
   • bandă de bagaje, carusel, conveyor → MT-BELT
   • escalator, lift, scară rulantă → MT-ESC
   • pasarelă de îmbarcare, jet bridge, poartă blocată → MT-JBRIDGE
   • coadă foarte mare, aglomerare, flux de pasageri → OP-QUEUE
   • sistem căzut, aplicație, rețea, internet, check-in IT → OP-IT
   • orice altceva specific aeroportului → OP-OTHER
8. Dacă ezitați între un cod specific și OP-OTHER, alegeți codul specific.
9. Pentru SF-* și SC-* pune urgency critical/high, chiar dacă textul nu spune explicit.
10. Nu folosi OP-OTHER dacă un cod din ghid se potrivește; OP-OTHER este ULTIMA opțiune."""

JSON_SCHEMA_PROMPT = """SCHEMA DE RĂSPUNS
{"incident_code": "<cod din listă>", "urgency": "low|medium|high|critical", "confidence": 0.0, "rationale": "<max 12 cuvinte>"}"""

FEW_SHOT_PROMPT = """EXEMPLE (intrare → ieșire)
"Este fum gros lângă poarta 12" → {"incident_code": "SF-FIRE", "urgency": "critical", "confidence": 0.95, "rationale": "fum, pericol de incendiu"}
"Un bărbat agitat amenință personalul la control" → {"incident_code": "SC-BEHAV", "urgency": "high", "confidence": 0.9, "rationale": "persoană agresivă în zona de securitate"}
"Banda de bagaje din terminal 2 s-a oprit" → {"incident_code": "MT-BELT", "urgency": "high", "confidence": 0.95, "rationale": "bandă bagaje defectă"}
"Cineva a intrat în zona restricționată de lângă poarta 5" → {"incident_code": "SC-ACCESS", "urgency": "critical", "confidence": 0.93, "rationale": "acces neautorizat în zonă restricționată"}
"Un bagaj a fost lăsat nesupravegheat în terminal" → {"incident_code": "SC-BAG", "urgency": "high", "confidence": 0.92, "rationale": "bagaj nesupravegheat"}

Top 3 demo includes a smoke/fire report — when the word fum/foc/incendiu appears, the answer is SF-FIRE."""

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
            FEW_SHOT_PROMPT,
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
        classification = Classification(
            incident_code=incident_type.code,
            urgency=escalate_urgency(incident_type.urgency, parsed.get("urgency")),
            confidence=confidence,
            rationale=rationale or "clasificare AI",
            ai_source="ollama",
            latency_ms=raw.get("latency_ms"),
        )
        if hint is None:
            classification = apply_classification_guards(
                taxonomy, transcript, classification
            )
        return classification
    except (ValueError, KeyError) as exc:
        logger.warning("Ollama returned unusable classification: %s", exc)
        return fallback_classify(taxonomy, transcript, hint_code)


# Unambiguous Romanian triggers. A 1.5B model occasionally confuses smoke with
# FOD or suspicion with OP-OTHER; these guards make the demo-critical cases
# deterministic while the prompt does the rest. Ordered: first match wins.
_KEYWORD_GUARDS: tuple[tuple[str, tuple[str, ...]], ...] = (
    (
        "SF-FIRE",
        ("fum", "foc", "incendiu", "flacăr", "flacar", "scânte", "scante", "arde"),
    ),
    # Mechanical failures before security: "banda de bagaje" must be MT-BELT,
    # not SC-BAG just because the word bagaj appears.
    (
        "MT-BELT",
        ("bandă", "banda", "carusel", "conveyor"),
    ),
    (
        "MT-ESC",
        ("escalator", "scară rulantă", "scara rulanta", "lift"),
    ),
    (
        "MT-JBRIDGE",
        ("pasarel", "jet bridge", "jetbridge"),
    ),
    (
        "SC-ACCESS",
        (
            "acces neautorizat", "zona restricționat", "zona restrictionat",
            "efrac", "a intrat fără", "a intrat fara", "intrat ilegal",
            "fără drept", "fara drept",
        ),
    ),
    (
        "SC-BAG",
        (
            "bagaj nesupravegheat", "bagaj abandonat", "bagaj suspect",
            "bagaj lăsat", "bagaj lasat", "valiz", "geamantan", "calet",
        ),
    ),
    (
        "SC-BEHAV",
        ("suspect", "agresiv", "agitat", "ameninț", "amenint", "comportament"),
    ),
    (
        "OP-QUEUE",
        ("coadă", "coada", "aglomer"),
    ),
)


def apply_classification_guards(
    taxonomy: Taxonomy, transcript: str, classification: Classification
) -> Classification:
    """Deterministic keyword override for demo-critical, unambiguous reports.

    Keeps `ai_source` as "ollama" (a new enum value would break the Dart
    contract); the rationale records which grounded word won. A catch-all
    OP-OTHER is always pushed to the dispatcher by capping confidence.
    """
    text = (transcript or "").lower()

    if classification.incident_code == "OP-OTHER" and classification.confidence > 0.55:
        classification = replace(
            classification,
            confidence=0.55,
            rationale=(
                classification.rationale + " [catch-all: verificare dispecer]"
            ).strip()[:200],
        )

    for code, words in _KEYWORD_GUARDS:
        matched = next((word for word in words if word in text), None)
        if matched is None:
            continue
        if classification.incident_code == code:
            break
        target = taxonomy.by_code(code)
        if target is None:
            continue
        urgency = classification.urgency
        if URGENCY_LEVELS.index(target.urgency) > URGENCY_LEVELS.index(urgency):
            urgency = target.urgency
        logger.info(
            "keyword guard: %s -> %s (matched %r, was %s/%.2f)",
            classification.incident_code,
            code,
            matched,
            classification.incident_code,
            classification.confidence,
        )
        return replace(
            classification,
            incident_code=code,
            urgency=urgency,
            confidence=max(min(classification.confidence, 0.95), 0.80),
            rationale=(
                classification.rationale + f" [ghid cheie: {matched}]"
            ).strip()[:200],
        )
    return classification


# ─────────────────────────────────────────────────────────────────────────────
# CONVERSATIONAL /analyze — contract used by the reporter flow (lib/core/)
#
# The app asks one question per turn, speaks it, appends the answer to the
# transcript and posts again with `clarifications_asked + 1`. The server keeps
# the slot-filling logic, so the client never decides what is missing.
#
# Hard rules (agreed with F1):
#   • at most MAX_CLARIFICATIONS questions, then classify anyway;
#   • when it stops while still incomplete/low-confidence, confidence is capped
#     at 0.40 so the ticket always lands in the dispatcher 5-second window;
#   • the button menu is always a valid fallback (hint_code path, no questions).
# ─────────────────────────────────────────────────────────────────────────────
MAX_CLARIFICATIONS = 3
REQUIRED_SLOTS: tuple[str, ...] = ("incident_code", "location")

QUESTION_TYPE = (
    "Ce fel de problemă este: siguranță/incendiu, securitate, mentenanță sau operațional?"
)
QUESTION_LOCATION = "Unde se întâmplă exact? (terminal, poartă sau zonă)"
QUESTION_DETAIL = "Poți descrie pe scurt ce vezi sau ce s-a întâmplat?"
QUESTION_PEOPLE = "Este cineva în pericol în acest moment?"

_LOCATION_PATTERNS: tuple[tuple[str, str], ...] = (
    (r"\bterminal(?:ul)?\s*([a-z0-9]+)", "Terminal {0}"),
    (r"\b(t\d)\b", "{0}"),
    (r"\bpoart[aă]?\s*(?:nr\.?\s*)?([a-z0-9]+)", "Poarta {0}"),
    (r"\bgate\s*([a-z0-9]+)", "Gate {0}"),
    (r"\bband[aă]?\s*(?:de\s*bagaje\s*)?(?:nr\.?\s*)?([a-z0-9]+)", "Banda {0}"),
    (
        r"\bzona?\s+([a-zăâîșț0-9]+(?:\s+[a-zăâîșț0-9]+){0,2})",
        "Zona {0}",
    ),
)

_LOCATION_KEYWORDS: tuple[tuple[str, str], ...] = (
    ("control securitate", "Control securitate"),
    ("security", "Control securitate"),
    ("check-in", "Check-in"),
    ("check in", "Check-in"),
    ("îmbarcare", "Zona de îmbarcare"),
    ("imbarcare", "Zona de îmbarcare"),
    ("parcare", "Parcare"),
    ("pistă", "Pistă"),
    ("pista", "Pistă"),
    ("platformă", "Platformă"),
    ("platforma", "Platformă"),
    ("pasarelă", "Pasarelă"),
    ("pasarela", "Pasarelă"),
    ("bagaje", "Zona bagaje"),
)

_PEOPLE_AT_RISK_TRUE: tuple[str, ...] = (
    "rănit",
    "ranit",
    "în pericol",
    "in pericol",
    "victim",
    "căzut",
    "cazut",
    "leșin",
    "lesin",
    "sânge",
    "sange",
    "panică",
    "panica",
    "evacu",
    "blocat în lift",
    "blocat in lift",
)
_PEOPLE_AT_RISK_FALSE: tuple[str, ...] = (
    "nimeni",
    "nicio persoană",
    "nicio persoana",
    "nici o persoană",
    "nici o persoana",
    "fără persoane",
    "fara persoane",
    "gol",
)


_LOCATION_TRAILING_STOPWORDS: tuple[str, ...] = (
    "și", "si", "sau", "dacă", "daca", "când", "cand", "unde", "care",
    "este", "sunt", "se", "a", "al", "ale", "lângă", "langa", "aproape",
    "din", "de", "la", "pe", "în", "in", "cu", "pentru", "către", "catre",
)


def extract_location(transcript: str) -> str:
    """Best-effort location label from free text (Romanian + a few English)."""
    if not transcript:
        return ""
    text = transcript.lower()
    for pattern, template in _LOCATION_PATTERNS:
        match = re.search(pattern, text)
        if match:
            value = match.group(1).strip()
            # "zona de îmbarcare și" -> "Zona de îmbarcare"
            while True:
                parts = value.split()
                if len(parts) > 1 and parts[-1] in _LOCATION_TRAILING_STOPWORDS:
                    value = " ".join(parts[:-1])
                    continue
                break
            if value:
                label = template.format(value)
                return label[:1].upper() + label[1:]
    for keyword, label in _LOCATION_KEYWORDS:
        if keyword in text:
            return label
    return ""


def detect_people_at_risk(transcript: str) -> bool | None:
    """True/False when the transcript states it, None when unknown.

    Negations are checked first ("nimeni nu este rănit" must be False).
    """
    text = (transcript or "").lower()
    if any(word in text for word in _PEOPLE_AT_RISK_FALSE):
        return False
    if any(word in text for word in _PEOPLE_AT_RISK_TRUE):
        return True
    return None


def next_question(
    missing: tuple[str, ...],
    confidence: float,
    urgency: str,
    people_at_risk: bool | None,
    asked: int,
) -> str | None:
    if asked >= MAX_CLARIFICATIONS:
        return None
    if "incident_code" in missing:
        return QUESTION_TYPE
    if "location" in missing:
        return QUESTION_LOCATION
    if confidence < settings.confidence_threshold:
        return QUESTION_DETAIL
    if people_at_risk is None and urgency in ("high", "critical"):
        return QUESTION_PEOPLE
    return None


@dataclass(frozen=True)
class ConversationState:
    fields: dict[str, Any]
    missing: tuple[str, ...]
    question: str | None
    clarifications_asked: int
    classification: Classification

    def to_wire(self) -> dict[str, Any]:
        return {
            "fields": self.fields,
            "missing": list(self.missing),
            "question": self.question,
            "clarifications_asked": self.clarifications_asked,
            "max_clarifications": MAX_CLARIFICATIONS,
            "ready": self.question is None,
            "classification": self.classification.to_wire(),
        }


async def analyze_conversation(
    ollama: OllamaClient,
    taxonomy: Taxonomy,
    transcript: str,
    location_label: str,
    hint_code: str | None = None,
    known_incident_code: str | None = None,
    clarifications_asked: int = 0,
) -> ConversationState:
    """One conversational turn: classify + report missing slots + next question."""
    asked = max(0, min(int(clarifications_asked or 0), 10))

    known = taxonomy.by_code(known_incident_code)
    if known is not None:
        classification = Classification(
            incident_code=known.code,
            urgency=known.urgency,
            confidence=1.0,
            rationale="cod confirmat într-un pas anterior",
            ai_source="manual",
        )
    else:
        classification = await analyze_report(
            ollama, taxonomy, transcript, location_label, hint_code, use_ai=True
        )

    incident_type = taxonomy.by_code(classification.incident_code)

    # Slot 1: location — prefer the structured location from the app, then the text.
    location = (location_label or "").strip()
    if not location or location.lower() in {
        "locație nespecificată",
        "locatie nespecificata",
        "locație nespecificata",
    }:
        location = extract_location(transcript)

    # Slot 2: is anyone in danger? (optional, only asked on high/critical)
    people_at_risk = detect_people_at_risk(transcript)

    fields: dict[str, Any] = {
        "incident_code": classification.incident_code,
        "label_ro": incident_type.label_ro if incident_type else None,
        "location": location,
        "people_at_risk": people_at_risk,
        "urgency": classification.urgency,
        "confidence": classification.confidence,
        "ai_source": classification.ai_source,
        "rationale": classification.rationale,
    }
    missing = tuple(slot for slot in REQUIRED_SLOTS if not fields.get(slot))

    question = next_question(
        missing,
        classification.confidence,
        classification.urgency,
        people_at_risk,
        asked,
    )

    # If we stop while still incomplete / unsure, force the dispatcher path.
    if question is None and (
        missing or classification.confidence < settings.confidence_threshold
    ):
        capped = min(classification.confidence, 0.40)
        classification = replace(
            classification,
            confidence=capped,
            rationale=(
                classification.rationale
                + " [informații insuficiente: trimis la dispecer]"
            ).strip()[:200],
        )
        fields["confidence"] = capped
        fields["rationale"] = classification.rationale

    logger.info(
        "analyze turn: code=%s conf=%.2f missing=%s asked=%d question=%s",
        classification.incident_code,
        classification.confidence,
        ",".join(missing) or "-",
        asked,
        question or "-",
    )
    return ConversationState(
        fields=fields,
        missing=missing,
        question=question,
        clarifications_asked=asked,
        classification=classification,
    )
