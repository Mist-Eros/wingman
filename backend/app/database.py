"""SQLite persistence for tickets.

The demo still keeps a fast in-memory copy for WSS reads, but every mutation is
written through to a real SQLite file. On startup the store reloads the file, so
a backend restart no longer wipes reports, photos, votes or history.
"""

from __future__ import annotations

import json
import logging
import sqlite3
import threading
from pathlib import Path
from typing import Any, Iterable

logger = logging.getLogger("airport.database")


class TicketDatabase:
    def __init__(self, path: str | Path) -> None:
        self.path = Path(path)
        self.path.parent.mkdir(parents=True, exist_ok=True)
        self._lock = threading.Lock()
        self._connection = sqlite3.connect(
            str(self.path),
            check_same_thread=False,
            timeout=10,
        )
        self._connection.row_factory = sqlite3.Row
        with self._lock:
            self._connection.execute("PRAGMA journal_mode=WAL")
            self._connection.execute("PRAGMA synchronous=NORMAL")
            self._connection.execute("""
                CREATE TABLE IF NOT EXISTS tickets (
                    id TEXT PRIMARY KEY,
                    payload TEXT NOT NULL,
                    created_at TEXT,
                    updated_at TEXT,
                    version INTEGER NOT NULL DEFAULT 1
                )
                """)
            self._connection.execute("""
                CREATE INDEX IF NOT EXISTS idx_tickets_created_at
                ON tickets(created_at)
                """)
            self._connection.commit()

    def load_all(self) -> list[dict[str, Any]]:
        with self._lock:
            rows = self._connection.execute(
                "SELECT payload FROM tickets ORDER BY created_at ASC, id ASC"
            ).fetchall()
        tickets: list[dict[str, Any]] = []
        for row in rows:
            try:
                payload = json.loads(row["payload"])
                if isinstance(payload, dict) and payload.get("id"):
                    tickets.append(payload)
            except (TypeError, ValueError, json.JSONDecodeError) as error:
                logger.warning("Skipping corrupt ticket row: %s", error)
        return tickets

    def upsert(self, ticket: dict[str, Any]) -> None:
        ticket_id = str(ticket.get("id") or "")
        if not ticket_id:
            raise ValueError("cannot persist a ticket without id")
        payload = json.dumps(ticket, ensure_ascii=False, default=str)
        with self._lock:
            self._connection.execute(
                """
                INSERT INTO tickets(id, payload, created_at, updated_at, version)
                VALUES (?, ?, ?, ?, ?)
                ON CONFLICT(id) DO UPDATE SET
                    payload = excluded.payload,
                    created_at = excluded.created_at,
                    updated_at = excluded.updated_at,
                    version = excluded.version
                """,
                (
                    ticket_id,
                    payload,
                    str(ticket.get("created_at") or ""),
                    str(ticket.get("updated_at") or ""),
                    int(ticket.get("version") or 1),
                ),
            )
            self._connection.commit()

    def delete_many(self, ticket_ids: Iterable[str]) -> None:
        ids = [str(ticket_id) for ticket_id in ticket_ids]
        if not ids:
            return
        placeholders = ",".join("?" for _ in ids)
        with self._lock:
            self._connection.execute(
                f"DELETE FROM tickets WHERE id IN ({placeholders})",  # noqa: S608
                ids,
            )
            self._connection.commit()

    def clear(self) -> int:
        with self._lock:
            removed = int(
                self._connection.execute("SELECT COUNT(*) FROM tickets").fetchone()[0]
            )
            self._connection.execute("DELETE FROM tickets")
            self._connection.commit()
        return removed

    def count(self) -> int:
        with self._lock:
            return int(
                self._connection.execute("SELECT COUNT(*) FROM tickets").fetchone()[0]
            )

    def close(self) -> None:
        with self._lock:
            self._connection.close()
