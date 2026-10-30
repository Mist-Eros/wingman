"""Local speech-to-text for the voice reporter flow (faster-whisper).

The reporter app records audio → `POST /api/transcribe` → text; the text then
goes through the normal `/api/analyze` conversation or `/api/reports`, so the
classification prompt never changes. This keeps the demo fully offline: no
cloud STT, no API key, nothing leaving the laptop.

Model: faster-whisper (CTranslate2), default `small` on CPU with int8 — a few
seconds of Romanian audio after the first model load. Override with
`WHISPER_MODEL` (tiny/base/small/medium), `WHISPER_DEVICE` (cpu/cuda) and
`WHISPER_COMPUTE_TYPE` (int8/float16/...).

Everything here degrades gracefully: if the package or the model is missing,
the endpoint answers 503 with a readable reason and the rest of the API keeps
working (menu-only demo remains possible).
"""

from __future__ import annotations

import asyncio
import importlib.util
import logging
import tempfile
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from .config import settings

logger = logging.getLogger("wingman.stt")

_MODEL_LOCK = asyncio.Lock()
_model: Any = None
_load_error: str | None = None

# Browsers/phones send different containers; faster-whisper decodes via PyAV so
# the suffix mostly helps it pick a demuxer.
_SUFFIX_BY_MIME = {
    "audio/mp4": ".m4a",
    "audio/m4a": ".m4a",
    "audio/x-m4a": ".m4a",
    "audio/mpeg": ".mp3",
    "audio/wav": ".wav",
    "audio/x-wav": ".wav",
    "audio/ogg": ".ogg",
    "audio/opus": ".opus",
    "audio/webm": ".webm",
    "audio/aac": ".aac",
    "audio/3gpp": ".3gp",
    "video/mp4": ".mp4",
}


@dataclass(frozen=True)
class Transcription:
    text: str
    language: str
    language_probability: float
    duration_ms: int
    model: str
    provider: str = "faster-whisper"
    latency_ms: int = 0

    def to_wire(self) -> dict[str, Any]:
        return {
            "text": self.text,
            "language": self.language,
            "language_probability": round(self.language_probability, 3),
            "duration_ms": self.duration_ms,
            "model": self.model,
            "provider": self.provider,
            "latency_ms": self.latency_ms,
        }


def stt_available() -> bool:
    """True when the Python package is importable (does not load the model)."""
    try:
        return importlib.util.find_spec("faster_whisper") is not None
    except (ImportError, ValueError):
        return False


def stt_error() -> str | None:
    """Last load error, or a package-missing hint."""
    if _load_error:
        return _load_error
    if not stt_available():
        return "faster-whisper is not installed (pip install -r requirements.txt)"
    return None


def _load_model() -> Any:
    global _model, _load_error
    if _model is not None:
        return _model
    try:
        from faster_whisper import WhisperModel
    except ImportError as exc:  # pragma: no cover - depends on install
        _load_error = (
            "faster-whisper is not installed (pip install -r requirements.txt)"
        )
        raise RuntimeError(_load_error) from exc

    started = time.perf_counter()
    logger.info(
        "loading faster-whisper: model=%s device=%s compute=%s",
        settings.whisper_model,
        settings.whisper_device,
        settings.whisper_compute_type,
    )
    try:
        _model = WhisperModel(
            settings.whisper_model,
            device=settings.whisper_device,
            compute_type=settings.whisper_compute_type,
        )
    except Exception as exc:  # model missing / bad config
        _load_error = f"faster-whisper model failed to load: {exc}"
        raise RuntimeError(_load_error) from exc
    logger.info("faster-whisper ready in %.1fs", time.perf_counter() - started)
    return _model


def _patch_pyav_open() -> None:
    """Compatibility shim for PyAV >= 19 with faster-whisper 1.2.x.

    faster-whisper still calls `av.open(..., metadata_errors="ignore")`, but
    PyAV 19 removed that keyword -> `TypeError`. Pinning an older PyAV is
    fragile on Windows (wheel availability), so we drop the unknown kwarg and
    let PyAV use its default error handling. Idempotent.
    """
    try:
        import av  # noqa: PLC0415 (optional dependency, imported lazily)
    except ImportError:
        return
    original = getattr(av, "open", None)
    if original is None or getattr(original, "_wingman_pyav_patched", False):
        return

    def _open_without_metadata_errors(*args: Any, **kwargs: Any) -> Any:
        kwargs.pop("metadata_errors", None)
        return original(*args, **kwargs)

    _open_without_metadata_errors._wingman_pyav_patched = True  # type: ignore[attr-defined]
    av.open = _open_without_metadata_errors  # type: ignore[assignment]
    logger.debug("patched av.open for faster-whisper compatibility")


def _transcribe_sync(
    audio_bytes: bytes,
    language: str | None,
    mime_type: str,
) -> Transcription:
    _patch_pyav_open()
    model = _load_model()
    suffix = _SUFFIX_BY_MIME.get((mime_type or "").lower(), ".audio")
    path: Path | None = None
    try:
        with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as handle:
            handle.write(audio_bytes)
            path = Path(handle.name)

        started = time.perf_counter()
        segments, info = model.transcribe(
            str(path),
            language=language,
            vad_filter=True,
            beam_size=1,
        )
        parts = [
            segment.text.strip()
            for segment in segments
            if getattr(segment, "text", None) and segment.text.strip()
        ]
        text = " ".join(parts).strip()
        latency_ms = int((time.perf_counter() - started) * 1000)
        return Transcription(
            text=text,
            language=str(getattr(info, "language", "") or ""),
            language_probability=float(
                getattr(info, "language_probability", 0.0) or 0.0
            ),
            duration_ms=int(float(getattr(info, "duration", 0.0) or 0.0) * 1000),
            model=settings.whisper_model,
            latency_ms=latency_ms,
        )
    finally:
        if path is not None:
            path.unlink(missing_ok=True)


async def transcribe_audio(
    audio_bytes: bytes,
    language: str | None = None,
    mime_type: str = "audio/mp4",
) -> Transcription:
    """Decode and transcribe audio bytes. Raises ValueError/RuntimeError."""
    if not audio_bytes:
        raise ValueError("empty audio payload")
    if len(audio_bytes) > settings.max_audio_bytes:
        raise ValueError(
            f"audio too large ({len(audio_bytes)} bytes > "
            f"{settings.max_audio_bytes} bytes)"
        )
    async with _MODEL_LOCK:  # the CTranslate2 model is not safe for parallel calls
        return await asyncio.to_thread(
            _transcribe_sync, audio_bytes, language, mime_type
        )
