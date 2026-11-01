"""Request bodies. Field names match the Dart client byte-for-byte; unknown

fields are rejected (`extra="forbid"`) so a frontend/backend contract drift
fails loudly during integration instead of silently losing data.
"""

from __future__ import annotations

from typing import Literal

from pydantic import BaseModel, ConfigDict, Field

UrgencyLiteral = Literal["low", "medium", "high", "critical"]
SourceLiteral = Literal["voice", "menu"]


class LocationIn(BaseModel):
    model_config = ConfigDict(extra="ignore")

    terminal: str = ""
    zone: str = ""
    lat: float | None = None
    lng: float | None = None
    note: str | None = None


class ReportIn(BaseModel):
    """POST /api/reports — mirrors Dart `ReportDraft.toJson()`."""

    model_config = ConfigDict(extra="forbid")

    source: SourceLiteral = "voice"
    transcript: str = Field(min_length=1, max_length=4000)
    reporter_id: str = Field(default="anon", max_length=120)
    reporter_name: str = Field(default="Anonim", max_length=120)
    location: LocationIn = Field(default_factory=LocationIn)

    # Menu flow: the reporter picked a type. Server trusts it unless use_ai.
    hint_code: str | None = Field(default=None, max_length=40)
    use_ai: bool = True

    # Optional photo (base64 JPEG/PNG). Not mandatory: dangerous scenes often
    # cannot wait for a camera.
    photo_base64: str | None = Field(default=None, max_length=2_500_000)

    # DEMO-ONLY: forces the low-confidence path so the 5-second dispatcher
    # override window can be triggered deterministically during rehearsal and
    # during the judged demo. The mobile app never sends this field.
    force_override: bool = False

    # DEMO-ONLY: pin the quorum for seeded/controlled cases. Normal app
    # reports leave this unset and use the domain quorum policy.
    quorum_override: int | None = Field(default=None, ge=1, le=8)


class AnalyzeIn(BaseModel):
    """POST /api/analyze — one conversational turn (no ticket is created).

    The reporter app sends the accumulated transcript, how many questions it
    already asked and (optionally) the incident code confirmed in a previous
    turn. It receives the extracted fields, the missing slots and the next
    question to display/speak — or `question: null` when it may submit.
    """

    model_config = ConfigDict(extra="forbid")

    transcript: str = Field(min_length=1, max_length=4000)
    location: LocationIn = Field(default_factory=LocationIn)
    hint_code: str | None = Field(default=None, max_length=40)
    clarifications_asked: int = Field(default=0, ge=0, le=10)
    known_incident_code: str | None = Field(default=None, max_length=40)


class TranscribeIn(BaseModel):
    """POST /api/transcribe — audio -> text for the voice reporter flow.

    JSON + base64 because the Flutter client (dart:io only) has no multipart
    encoder; the 25 MB cap is enforced server-side. The returned text is fed to
    `/api/analyze` (conversation) or `/api/reports` (submission) unchanged.

    `language` is optional; omit it (or send "auto") to let Whisper detect.
    """

    model_config = ConfigDict(extra="forbid")

    audio_base64: str = Field(min_length=8)
    mime_type: str = Field(default="audio/mp4", max_length=100)
    language: str | None = Field(default=None, min_length=2, max_length=8)


class DispatcherActionIn(BaseModel):
    model_config = ConfigDict(extra="forbid")

    dispatcher_id: str | None = Field(default=None, max_length=120)
    dispatcher_name: str | None = Field(default=None, max_length=120)


class DenyIn(DispatcherActionIn):
    reason: str | None = Field(default=None, max_length=500)


class OverrideIn(DispatcherActionIn):
    incident_code: str = Field(min_length=2, max_length=40)
    urgency: UrgencyLiteral | None = None
    reason: str | None = Field(default=None, max_length=500)


class TicketEditIn(BaseModel):
    model_config = ConfigDict(extra="forbid")

    reporter_id: str = Field(min_length=1, max_length=120)
    transcript: str | None = Field(default=None, min_length=1, max_length=4000)
    photo_base64: str | None = Field(default=None)


class ResolutionConfirmIn(DispatcherActionIn):
    pass


class JoinIn(BaseModel):
    model_config = ConfigDict(extra="forbid")

    crew_id: str = Field(min_length=1, max_length=120)
    crew_name: str | None = Field(default=None, max_length=120)
    # Responder's department; exactly one responder per primary department.
    department: str = Field(min_length=1, max_length=40)


class VoteIn(BaseModel):
    model_config = ConfigDict(extra="forbid")

    crew_id: str = Field(min_length=1, max_length=120)
    approve: bool = True
