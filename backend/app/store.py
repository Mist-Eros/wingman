"""In-memory ticket store + WebSocket hub + the 5-second override timer.

Single source of truth for ticket state. Everything mutating happens under one
`asyncio.Lock`; broadcasts happen AFTER the lock is released (a slow phone must
never block a dispatcher action).
"""

from __future__ import annotations

import asyncio
import copy
import logging
import uuid
from datetime import datetime, timedelta, timezone
from typing import Any

from fastapi import WebSocket

from .ai import Classification
from .config import Settings
from .taxonomy import URGENCY_LEVELS, Taxonomy

logger = logging.getLogger("airport.store")

ALLOWED_STATUSES: tuple[str, ...] = (
    "pending_override",
    "dispatched",
    "in_progress",
    "resolved",
    "denied",
)


class NotFound(Exception):
    """Ticket id does not exist."""


class Conflict(Exception):
    """Action is not legal for the ticket's current status."""


def utc_now() -> str:
    return (
        datetime.now(timezone.utc)
        .isoformat(timespec="milliseconds")
        .replace("+00:00", "Z")
    )


def _deadline_iso(seconds: float) -> str:
    deadline = datetime.now(timezone.utc) + timedelta(seconds=max(0.0, seconds))
    return deadline.isoformat(timespec="milliseconds").replace("+00:00", "Z")


class Hub:
    """Broadcast fan-out to every connected dashboard / crew phone."""

    def __init__(self) -> None:
        self._clients: set[WebSocket] = set()
        self._lock = asyncio.Lock()

    @property
    def count(self) -> int:
        return len(self._clients)

    async def register(self, websocket: WebSocket) -> None:
        async with self._lock:
            self._clients.add(websocket)

    async def unregister(self, websocket: WebSocket) -> None:
        async with self._lock:
            self._clients.discard(websocket)

    async def broadcast(self, event_type: str, data: dict[str, Any]) -> int:
        """Sends one event to every client; drops dead sockets. Never raises."""
        payload = {"type": event_type, "ts": utc_now(), "data": data}
        async with self._lock:
            clients = list(self._clients)
        if not clients:
            return 0
        results = await asyncio.gather(
            *(self._safe_send(client, payload) for client in clients),
            return_exceptions=True,
        )
        sent = 0
        for client, result in zip(clients, results):
            if result is True:
                sent += 1
            else:
                await self.unregister(client)
        return sent

    @staticmethod
    async def _safe_send(websocket: WebSocket, payload: dict[str, Any]) -> bool:
        try:
            await websocket.send_json(payload)
            return True
        except Exception:  # noqa: BLE001 - a dead phone must not break broadcast
            return False


class TicketStore:
    def __init__(self, taxonomy: Taxonomy, hub: Hub, settings: Settings) -> None:
        self._taxonomy = taxonomy
        self._hub = hub
        self._settings = settings
        self._tickets: dict[str, dict[str, Any]] = {}
        self._order: list[str] = []  # creation order (oldest → newest)
        self._timers: dict[str, asyncio.Task[None]] = {}
        self._lock = asyncio.Lock()

    @property
    def count(self) -> int:
        return len(self._tickets)

    # ── create ────────────────────────────────────────────────────────────────
    async def create(
        self,
        *,
        source: str,
        transcript: str,
        reporter_id: str,
        reporter_name: str,
        location: dict[str, Any],
        classification: Classification,
    ) -> dict[str, Any]:
        incident_type = self._taxonomy.require(classification.incident_code)
        confidence = round(float(classification.confidence), 3)
        urgency = (
            classification.urgency
            if classification.urgency in URGENCY_LEVELS
            else incident_type.urgency
        )
        now = utc_now()

        # No pending/override state: every report is dispatched immediately.
        # The dispatcher can still deny or reclassify it from the live queue.
        ticket: dict[str, Any] = {
            "id": str(uuid.uuid4()),
            "incident_code": incident_type.code,
            "label_ro": incident_type.label_ro,
            "category": incident_type.category,
            "urgency": urgency,
            "status": "dispatched",
            "source": source,
            "reporter_id": reporter_id,
            "reporter_name": reporter_name,
            "transcript": transcript,
            "location": {
                "terminal": str(location.get("terminal") or ""),
                "zone": str(location.get("zone") or ""),
                "lat": location.get("lat"),
                "lng": location.get("lng"),
                "note": location.get("note"),
            },
            "confidence": confidence,
            "ai_source": classification.ai_source,
            "ai_rationale": classification.rationale,
            "primary_departments": list(incident_type.primary_departments),
            "standby_departments": list(incident_type.standby_departments),
            "joined_crew_ids": [],
            "resolve_votes": 0,
            "resolve_voter_ids": [],
            "quorum": self._settings.resolve_quorum,
            "override_deadline": None,
            "dispatched_at": now,
            "resolved_at": None,
            "resolution_note": None,
            "decided_by": None,
            "created_at": now,
            "updated_at": now,
            "version": 1,
        }

        async with self._lock:
            self._tickets[ticket["id"]] = ticket
            self._order.append(ticket["id"])
            snapshot = copy.deepcopy(ticket)

        await self._hub.broadcast("ticket.created", {"ticket": snapshot})
        return snapshot

    # ── dispatcher actions ────────────────────────────────────────────────────
    async def confirm(
        self,
        ticket_id: str,
        dispatcher_id: str | None = None,
        dispatcher_name: str | None = None,
    ) -> dict[str, Any]:
        async with self._lock:
            ticket = self._require_ticket(ticket_id)
            if ticket["status"] == TicketStatus.RESOLVED:
                raise Conflict("Ticket already resolved")
            if ticket["status"] == TicketStatus.DENIED:
                raise Conflict("Ticket was denied")
            self._cancel_timer(ticket_id)
            if ticket["status"] == "pending_override":
                ticket["status"] = "dispatched"
                ticket["dispatched_at"] = utc_now()
            ticket["override_deadline"] = None
            ticket["decided_by"] = self._dispatcher_label(
                dispatcher_id, dispatcher_name
            )
            self._bump(ticket)
            snapshot = copy.deepcopy(ticket)

        await self._hub.broadcast(
            "ticket.updated", {"ticket": snapshot, "action": "confirmed"}
        )
        return snapshot

    async def deny(
        self,
        ticket_id: str,
        reason: str | None = None,
        dispatcher_id: str | None = None,
        dispatcher_name: str | None = None,
    ) -> dict[str, Any]:
        async with self._lock:
            ticket = self._require_ticket(ticket_id)
            if ticket["status"] in ("resolved", "denied"):
                raise Conflict("Ticket is already closed")
            self._cancel_timer(ticket_id)
            ticket["status"] = "denied"
            ticket["override_deadline"] = None
            ticket["resolution_note"] = reason or "Respins de dispecer"
            ticket["decided_by"] = self._dispatcher_label(
                dispatcher_id, dispatcher_name
            )
            self._bump(ticket)
            snapshot = copy.deepcopy(ticket)

        await self._hub.broadcast(
            "ticket.updated", {"ticket": snapshot, "action": "denied"}
        )
        return snapshot

    async def override(
        self,
        ticket_id: str,
        *,
        incident_code: str,
        urgency: str | None = None,
        reason: str | None = None,
        dispatcher_id: str | None = None,
        dispatcher_name: str | None = None,
    ) -> dict[str, Any]:
        incident_type = self._taxonomy.require(incident_code)
        async with self._lock:
            ticket = self._require_ticket(ticket_id)
            if ticket["status"] in ("resolved", "denied"):
                raise Conflict("Ticket is already closed")
            self._cancel_timer(ticket_id)
            ticket["incident_code"] = incident_type.code
            ticket["label_ro"] = incident_type.label_ro
            ticket["category"] = incident_type.category
            ticket["urgency"] = self._escalate(incident_type.urgency, urgency)
            ticket["primary_departments"] = list(incident_type.primary_departments)
            ticket["standby_departments"] = list(incident_type.standby_departments)
            ticket["confidence"] = 1.0
            ticket["ai_source"] = "manual"
            ticket["ai_rationale"] = reason or "Reclasificat de dispecer"
            if ticket["status"] != "in_progress":
                ticket["status"] = "dispatched"
            ticket["dispatched_at"] = ticket["dispatched_at"] or utc_now()
            ticket["override_deadline"] = None
            ticket["decided_by"] = self._dispatcher_label(
                dispatcher_id, dispatcher_name
            )
            self._bump(ticket)
            snapshot = copy.deepcopy(ticket)

        await self._hub.broadcast(
            "ticket.updated", {"ticket": snapshot, "action": "reclassified"}
        )
        return snapshot

    # ── crew actions ──────────────────────────────────────────────────────────
    async def join(
        self,
        ticket_id: str,
        crew_id: str,
        crew_name: str | None = None,
    ) -> dict[str, Any]:
        async with self._lock:
            ticket = self._require_ticket(ticket_id)
            if ticket["status"] in ("pending_override", "resolved", "denied"):
                raise Conflict("Only dispatched or in-progress tickets can be joined")
            changed = False
            if crew_id not in ticket["joined_crew_ids"]:
                ticket["joined_crew_ids"].append(crew_id)
                changed = True
            if ticket["status"] == "dispatched":
                ticket["status"] = "in_progress"
                changed = True
            if changed:
                self._bump(ticket)
            snapshot = copy.deepcopy(ticket)

        if changed:
            await self._hub.broadcast(
                "ticket.updated",
                {
                    "ticket": snapshot,
                    "action": "joined",
                    "crew_id": crew_id,
                    "crew_name": crew_name,
                },
            )
        return snapshot

    async def vote(
        self,
        ticket_id: str,
        crew_id: str,
        approve: bool = True,
    ) -> dict[str, Any]:
        async with self._lock:
            ticket = self._require_ticket(ticket_id)
            if ticket["status"] in ("pending_override", "resolved", "denied"):
                raise Conflict("Ticket is not open for voting")
            if crew_id not in ticket["joined_crew_ids"]:
                raise Conflict("Join the ticket before voting")
            changed = False
            resolved_now = False
            if approve and crew_id not in ticket["resolve_voter_ids"]:
                ticket["resolve_voter_ids"].append(crew_id)
                ticket["resolve_votes"] = len(ticket["resolve_voter_ids"])
                changed = True
                if ticket["resolve_votes"] >= max(1, int(ticket["quorum"])):
                    ticket["status"] = "resolved"
                    ticket["resolved_at"] = utc_now()
                    ticket["resolution_note"] = (
                        ticket["resolution_note"]
                        or f"Rezolvat prin vot ({ticket['resolve_votes']} aprobări)"
                    )
                    resolved_now = True
            if changed:
                self._bump(ticket)
            snapshot = copy.deepcopy(ticket)

        if changed:
            await self._hub.broadcast(
                "ticket.resolved" if resolved_now else "ticket.updated",
                {
                    "ticket": snapshot,
                    "action": "voted",
                    "crew_id": crew_id,
                },
            )
        return snapshot

    # ── reads ─────────────────────────────────────────────────────────────────
    async def list_tickets(self, status: str | None = None) -> list[dict[str, Any]]:
        if status is not None and status not in ALLOWED_STATUSES:
            raise ValueError(
                f"Unknown status {status!r}. Allowed: {', '.join(ALLOWED_STATUSES)}"
            )
        async with self._lock:
            items = [
                copy.deepcopy(self._tickets[ticket_id])
                for ticket_id in reversed(self._order)
                if status is None or self._tickets[ticket_id]["status"] == status
            ]
        return items

    async def get(self, ticket_id: str) -> dict[str, Any]:
        async with self._lock:
            return copy.deepcopy(self._require_ticket(ticket_id))

    async def reset(self) -> int:
        async with self._lock:
            for task in list(self._timers.values()):
                task.cancel()
            self._timers.clear()
            removed = len(self._tickets)
            self._tickets.clear()
            self._order.clear()
        await self._hub.broadcast("store.reset", {"removed": removed})
        return removed

    async def clear_history(self) -> int:
        """Remove every terminal ticket (resolved/denied) and broadcast it."""
        async with self._lock:
            removed_ids = [
                ticket_id
                for ticket_id in self._order
                if self._tickets[ticket_id]["status"] in ("resolved", "denied")
            ]
            for ticket_id in removed_ids:
                self._tickets.pop(ticket_id, None)
            if removed_ids:
                removed = set(removed_ids)
                self._order = [
                    ticket_id for ticket_id in self._order if ticket_id not in removed
                ]
        if removed_ids:
            await self._hub.broadcast(
                "history.cleared",
                {"ticket_ids": removed_ids, "count": len(removed_ids)},
            )
        return len(removed_ids)

    # ── 5-second override window ──────────────────────────────────────────────
    def _schedule_auto_dispatch(self, ticket_id: str) -> None:
        self._cancel_timer(ticket_id)
        task = asyncio.create_task(
            self._auto_dispatch(ticket_id, self._settings.override_window_seconds),
            name=f"auto-dispatch-{ticket_id}",
        )
        self._timers[ticket_id] = task

        def _cleanup(_finished: asyncio.Task[None], key: str = ticket_id) -> None:
            current = self._timers.get(key)
            if current is _finished:
                self._timers.pop(key, None)

        task.add_done_callback(_cleanup)

    def _cancel_timer(self, ticket_id: str) -> None:
        task = self._timers.pop(ticket_id, None)
        if task is not None and not task.done():
            task.cancel()

    async def _auto_dispatch(self, ticket_id: str, delay: float) -> None:
        try:
            await asyncio.sleep(delay)
        except asyncio.CancelledError:
            return

        async with self._lock:
            ticket = self._tickets.get(ticket_id)
            if ticket is None or ticket["status"] != "pending_override":
                return
            ticket["status"] = "dispatched"
            ticket["dispatched_at"] = utc_now()
            ticket["override_deadline"] = None
            ticket["decided_by"] = None
            ticket["resolution_note"] = (
                "Auto-dispecerizat după expirarea ferestrei de 5s"
            )
            self._bump(ticket)
            snapshot = copy.deepcopy(ticket)

        logger.info(
            "Auto-dispatched ticket %s (%s) after %.1fs without dispatcher action",
            ticket_id,
            snapshot["incident_code"],
            delay,
        )
        await self._hub.broadcast(
            "ticket.updated", {"ticket": snapshot, "action": "auto_dispatched"}
        )

    # ── helpers ───────────────────────────────────────────────────────────────
    def _require_ticket(self, ticket_id: str) -> dict[str, Any]:
        ticket = self._tickets.get(ticket_id)
        if ticket is None:
            raise NotFound(f"Ticket {ticket_id} not found")
        return ticket

    @staticmethod
    def _bump(ticket: dict[str, Any]) -> None:
        ticket["version"] = int(ticket.get("version", 1)) + 1
        ticket["updated_at"] = utc_now()

    @staticmethod
    def _dispatcher_label(
        dispatcher_id: str | None, dispatcher_name: str | None
    ) -> str:
        return dispatcher_name or dispatcher_id or "dispecer"

    @staticmethod
    def _escalate(default: str, requested: str | None) -> str:
        candidate = (requested or "").strip().lower()
        if candidate not in URGENCY_LEVELS:
            return default
        if URGENCY_LEVELS.index(candidate) >= URGENCY_LEVELS.index(default):
            return candidate
        return default


class TicketStatus:
    """String constants mirroring the Dart `TicketStatus` wire values."""

    PENDING_OVERRIDE = "pending_override"
    DISPATCHED = "dispatched"
    IN_PROGRESS = "in_progress"
    RESOLVED = "resolved"
    DENIED = "denied"
