"""Tests for the SQLite persistence layer."""

from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from app.database import TicketDatabase


def ticket(ticket_id: str, version: int = 1) -> dict:
    return {
        "id": ticket_id,
        "incident_code": "OP-MED",
        "status": "dispatched",
        "created_at": "2026-10-31T12:00:00.000Z",
        "updated_at": "2026-10-31T12:00:00.000Z",
        "version": version,
        "payload_note": "test",
    }


class TicketDatabaseTests(unittest.TestCase):
    def test_round_trip_survives_reopen(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "tickets.db"
            db = TicketDatabase(path)
            db.upsert(ticket("a"))
            db.upsert(ticket("b", version=2))
            self.assertEqual(db.count(), 2)
            db.close()

            reopened = TicketDatabase(path)
            rows = reopened.load_all()
            self.assertEqual([row["id"] for row in rows], ["a", "b"])
            self.assertEqual(reopened.count(), 2)
            reopened.close()

    def test_update_delete_and_clear(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            db = TicketDatabase(Path(tmp) / "tickets.db")
            db.upsert(ticket("a"))
            db.upsert(ticket("b"))
            db.upsert(ticket("a", version=3))
            rows = db.load_all()
            self.assertEqual(len(rows), 2)
            self.assertEqual(rows[0]["version"], 3)
            db.delete_many(["a"])
            self.assertEqual([row["id"] for row in db.load_all()], ["b"])
            self.assertEqual(db.clear(), 1)
            self.assertEqual(db.count(), 0)
            db.close()


if __name__ == "__main__":
    unittest.main()
