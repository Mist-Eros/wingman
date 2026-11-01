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
import threading
import logging
import tempfile
import unicodedata
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from .config import settings

logger = logging.getLogger("wingman.stt")

_MODEL_LOCK = asyncio.Lock()
_load_lock = threading.Lock()
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
    words: tuple[dict[str, Any], ...] = ()
    raw_text: str = ""
    corrected: bool = False

    def to_wire(self) -> dict[str, Any]:
        return {
            "text": self.text,
            "raw_text": self.raw_text,
            "corrected": self.corrected,
            "words": list(self.words),
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
    with _load_lock:
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


def warmup_stt() -> bool:
    """Load the Whisper model in the background so the first report is fast."""
    if not stt_available():
        return False
    try:
        _patch_pyav_open()
        _load_model()
        logger.info("Whisper model warmed up")
        return True
    except Exception as exc:  # noqa: BLE001 - startup must keep working
        logger.warning("Whisper warm-up failed: %s", exc)
        return False


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
            word_timestamps=True,
            condition_on_previous_text=False,
            temperature=0.0,
        )
        parts: list[str] = []
        words: list[dict[str, Any]] = []
        for segment in segments:
            segment_text = getattr(segment, "text", None)
            if segment_text and segment_text.strip():
                parts.append(segment_text.strip())
            # faster-whisper word tokens include leading spaces/punctuation.
            for word in getattr(segment, "words", None) or []:
                token = str(getattr(word, "word", "") or "").strip()
                if not token:
                    continue
                probability = float(getattr(word, "probability", 0.0) or 0.0)
                words.append(
                    {
                        "text": token,
                        "probability": round(max(0.0, min(1.0, probability)), 3),
                        "start": round(float(getattr(word, "start", 0.0) or 0.0), 2),
                        "end": round(float(getattr(word, "end", 0.0) or 0.0), 2),
                    }
                )
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
            words=tuple(words),
        )
    finally:
        if path is not None:
            path.unlink(missing_ok=True)


def align_words_to_corrected(
    raw_words: tuple[dict[str, Any], ...],
    corrected_text: str,
) -> tuple[dict[str, Any], ...]:
    """Map raw Whisper word probabilities onto the LLM-corrected sentence.

    Unchanged words keep their model probability; replaced/inserted words are
    marked low-confidence (0.35), so the reporter sees exactly what the LLM
    changed and can edit it. Pure deletions are dropped.
    """
    import difflib

    raw_tokens = [str(word.get("text") or "") for word in raw_words if word.get("text")]
    corrected_tokens = [token for token in corrected_text.split() if token]
    if not raw_tokens or not corrected_tokens:
        return raw_words
    matcher = difflib.SequenceMatcher(a=raw_tokens, b=corrected_tokens)
    aligned: list[dict[str, Any]] = []
    for tag, i1, i2, j1, j2 in matcher.get_opcodes():
        if tag == "equal":
            for offset, token in enumerate(corrected_tokens[j1:j2]):
                source = raw_words[i1 + offset]
                aligned.append(
                    {
                        "text": token,
                        "probability": source.get("probability", 0.0),
                        "start": source.get("start", 0.0),
                        "end": source.get("end", 0.0),
                    }
                )
        elif tag in ("replace", "insert"):
            for token in corrected_tokens[j1:j2]:
                aligned.append(
                    {
                        "text": token,
                        "probability": 0.35,
                        "start": 0.0,
                        "end": 0.0,
                    }
                )
    return tuple(aligned)


_NUMBER_WORDS = {
    "zero",
    "unu",
    "doi",
    "două",
    "doua",
    "trei",
    "patru",
    "cinci",
    "șase",
    "sase",
    "șapte",
    "sapte",
    "opt",
    "nouă",
    "noua",
    "zece",
    "unsprezece",
    "doisprezece",
    "treisprezece",
    "paisprezece",
    "cincisprezece",
    "șaisprezece",
    "saisprezece",
    "șaptesprezece",
    "saptesprezece",
    "optsprezece",
    "nouăsprezece",
    "nouasprezece",
    "douăzeci",
    "douazeci",
    "o",
    "un",
    "una",
    "one",
    "two",
    "three",
    "four",
    "five",
    "six",
    "seven",
    "eight",
    "nine",
    "ten",
    "eleven",
    "twelve",
    "thirteen",
    "fourteen",
    "fifteen",
    "sixteen",
    "seventeen",
    "eighteen",
    "nineteen",
    "twenty",
}


def _plain(text: str) -> str:
    return (
        unicodedata.normalize("NFKD", text)
        .encode("ascii", "ignore")
        .decode("ascii")
        .lower()
    )


def _is_number_token(token: str) -> bool:
    stripped = token.strip(".,!?;:()[]{}")
    return any(ch.isdigit() for ch in stripped) or stripped.lower() in _NUMBER_WORDS


def merge_corrected_transcript(
    raw_text: str,
    raw_words: tuple[dict[str, Any], ...],
    corrected_text: str,
) -> tuple[str, tuple[dict[str, Any], ...]]:
    """Apply only safe LLM corrections to a Whisper transcript.

    The small LLM is allowed to fix low-confidence words and diacritics. It may
    not replace high-confidence words, numbers, or insert/delete facts; those
    are the common hallucinations of a 1.5B model on short ASR text.
    """
    import difflib

    raw_tokens = raw_text.split()
    corrected_tokens = corrected_text.split()
    if not raw_tokens or not corrected_tokens:
        return raw_text, raw_words

    probabilities: list[float] = []
    for index in range(len(raw_tokens)):
        if index < len(raw_words):
            try:
                probabilities.append(float(raw_words[index].get("probability", 0.0)))
            except (TypeError, ValueError):
                probabilities.append(0.0)
        else:
            probabilities.append(0.0)

    matcher = difflib.SequenceMatcher(a=raw_tokens, b=corrected_tokens)
    out_tokens: list[str] = []
    out_words: list[dict[str, Any]] = []
    changed = False

    def append(token: str, probability: float) -> None:
        out_tokens.append(token)
        out_words.append(
            {
                "text": token,
                "probability": round(max(0.0, min(1.0, probability)), 3),
                "start": 0.0,
                "end": 0.0,
            }
        )

    for tag, i1, i2, j1, j2 in matcher.get_opcodes():
        if tag == "equal":
            for offset, token in enumerate(raw_tokens[i1:i2]):
                append(token, probabilities[i1 + offset])
            continue
        if tag == "insert":
            # Never let the LLM add new facts/words.
            continue
        if tag == "delete":
            # Keep high-confidence words; a low-confidence deletion is also kept
            # to avoid silently dropping information.
            for offset, token in enumerate(raw_tokens[i1:i2]):
                append(token, probabilities[i1 + offset])
            continue
        # replace: only low-confidence words or diacritic-only fixes
        corrected = corrected_tokens[j1:j2]
        cursor = 0
        for offset, raw_token in enumerate(raw_tokens[i1:i2]):
            probability = probabilities[i1 + offset]
            replacement = corrected[cursor] if cursor < len(corrected) else None
            if replacement is None:
                append(raw_token, probability)
                continue
            diacritic_only = _plain(replacement) == _plain(raw_token)
            number_change = _is_number_token(replacement) or _is_number_token(raw_token)
            if diacritic_only and not number_change:
                append(replacement, probability)
                changed = changed or replacement != raw_token
                cursor += 1
            elif probability < 0.75 and not number_change:
                append(replacement, 0.45)
                changed = True
                cursor += 1
            else:
                append(raw_token, probability)
                cursor += 1

    if not changed:
        return raw_text, raw_words
    return " ".join(out_tokens), tuple(out_words)


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
