"""Unit tests for admin statistics (pure function, no server)."""

from __future__ import annotations

import unittest
from datetime import datetime, timezone

from app.stats import build_stats


def ticket(
    code: str,
    created: str,
    *,
    reports: int = 1,
    status: str = "dispatched",
    resolved_at: str | None = None,
):
    return {
        "id": code + created,
        "incident_code": code,
        "label_ro": code + " label",
        "category": "operations",
        "urgency": "high",
        "status": status,
        "created_at": created,
        "resolved_at": resolved_at,
        "report_count": reports,
        "primary_departments": ["medical"],
    }


class StatsTests(unittest.TestCase):
    def setUp(self) -> None:
        self.now = datetime(2026, 10, 31, 12, 0, tzinfo=timezone.utc)
        self.tickets = [
            ticket("OP-MED", "2026-10-31T10:00:00.000Z", reports=2),
            ticket(
                "OP-MED",
                "2026-10-31T09:00:00.000Z",
                reports=1,
                status="resolved",
            ),
            ticket("SF-FIRE", "2026-10-30T08:00:00.000Z"),
            ticket("SF-FIRE", "2026-08-01T08:00:00.000Z"),
        ]

    def test_day_has_hourly_series_and_ticket_counts(self) -> None:
        stats = build_stats(self.tickets, period="day", now=self.now)
        self.assertEqual(len(stats["series"]), 24)
        # 10:00 and 09:00 on the 31st fall in the last 24h.
        self.assertEqual(stats["total_tickets"], 2)
        self.assertEqual(stats["total_reports"], 3)
        self.assertEqual(stats["resolved"], 1)
        self.assertEqual(stats["by_code"][0]["code"], "OP-MED")
        self.assertEqual(stats["by_code"][0]["count"], 2)

    def test_week_month_year_series_lengths(self) -> None:
        self.assertEqual(len(build_stats(self.tickets, period="week", now=self.now)["series"]), 7)
        self.assertEqual(len(build_stats(self.tickets, period="month", now=self.now)["series"]), 30)
        year = build_stats(self.tickets, period="year", now=self.now)
        self.assertEqual(len(year["series"]), 12)
        # The August ticket is inside the last 12 months.
        self.assertIn("SF-FIRE", [item["code"] for item in year["by_code"]])

    def test_average_handling_time_uses_resolved_tickets(self) -> None:
        handled = [
            ticket(
                "OP-MED",
                "2026-10-31T10:00:00.000Z",
                status="resolved",
                resolved_at="2026-10-31T10:30:00.000Z",
            ),
            ticket(
                "OP-MED",
                "2026-10-31T11:00:00.000Z",
                status="resolved",
                resolved_at="2026-10-31T11:10:00.000Z",
            ),
            ticket("OP-MED", "2026-10-31T11:30:00.000Z"),
        ]
        stats = build_stats(handled, period="day", now=self.now)
        self.assertEqual(stats["handled_count"], 2)
        self.assertEqual(stats["average_handling_seconds"], 1200)
        handled_bucket = next(
            point for point in stats["series"] if point["handled_count"] > 0
        )
        self.assertIn(handled_bucket["average_handling_seconds"], (600, 1800))

    def test_unknown_period_defaults_to_week(self) -> None:
        stats = build_stats(self.tickets, period="nope", now=self.now)
        self.assertEqual(stats["period"], "week")
        self.assertEqual(len(stats["series"]), 7)


if __name__ == "__main__":
    unittest.main()
