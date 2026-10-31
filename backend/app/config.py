"""Environment-driven settings. No .env parser dependency: `run.ps1` exports

the variables (or you set them in the shell). See backend/.env.example.
"""

from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path

# <repo>/backend
BASE_DIR = Path(__file__).resolve().parent.parent


def _env_str(name: str, default: str) -> str:
    value = os.getenv(name)
    if value is None or not value.strip():
        return default
    return value.strip()


def _env_bool(name: str, default: bool) -> bool:
    raw = os.getenv(name)
    if raw is None:
        return default
    return raw.strip().lower() in {"1", "true", "yes", "on"}


def _env_float(name: str, default: float) -> float:
    try:
        return float(os.getenv(name, ""))
    except (TypeError, ValueError):
        return default


def _env_int(name: str, default: int) -> int:
    try:
        return int(os.getenv(name, ""))
    except (TypeError, ValueError):
        return default


@dataclass(frozen=True)
class Settings:
    # Auth
    api_token: str

    # Ollama
    ollama_url: str
    ollama_model: str
    ollama_timeout_seconds: float

    # Classification policy
    confidence_threshold: float
    override_window_seconds: float

    # Crew resolution
    resolve_quorum: int

    # Speech-to-text (voice reporter flow, local faster-whisper)
    transcript_correction: bool
    transcript_correction_timeout: float
    whisper_model: str
    whisper_device: str
    whisper_compute_type: str
    max_audio_bytes: int

    # Dev conveniences
    allow_dev_reset: bool
    taxonomy_path: Path
    database_path: Path


def load_settings() -> Settings:
    return Settings(
        api_token=_env_str("API_TOKEN", "demo-token"),
        ollama_url=_env_str("OLLAMA_URL", "http://127.0.0.1:11434").rstrip("/"),
        ollama_model=_env_str("OLLAMA_MODEL", "qwen2.5:7b"),
        ollama_timeout_seconds=_env_float("OLLAMA_TIMEOUT", 25.0),
        confidence_threshold=_env_float("CONFIDENCE_THRESHOLD", 0.65),
        override_window_seconds=_env_float("OVERRIDE_WINDOW_SECONDS", 5.0),
        resolve_quorum=max(1, _env_int("RESOLVE_QUORUM", 2)),
        transcript_correction=_env_bool("TRANSCRIPT_CORRECTION", True),
        transcript_correction_timeout=_env_float("TRANSCRIPT_CORRECTION_TIMEOUT", 12.0),
        whisper_model=_env_str("WHISPER_MODEL", "small"),
        whisper_device=_env_str("WHISPER_DEVICE", "cpu"),
        whisper_compute_type=_env_str("WHISPER_COMPUTE_TYPE", "int8"),
        max_audio_bytes=max(1_000_000, _env_int("MAX_AUDIO_BYTES", 25 * 1024 * 1024)),
        allow_dev_reset=_env_bool("ENABLE_DEV_RESET", True),
        taxonomy_path=Path(_env_str("TAXONOMY_PATH", str(BASE_DIR / "taxonomy.json"))),
        database_path=Path(
            _env_str("DATABASE_PATH", str(BASE_DIR / "data" / "wingman.db"))
        ),
    )


settings = load_settings()
