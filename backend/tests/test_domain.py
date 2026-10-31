"""Unit tests for the backend domain policies (no server/AI needed).

Run from backend/:
    .venv\\Scripts\\python.exe -m unittest discover -s tests -v
"""

from __future__ import annotations

import unittest
from pathlib import Path

from app.domain import DomainConfig, QuorumConfig, RewardConfig, load_domain_config


def ticket(
    ticket_id: str,
    status: str,
    crew_ids: list[str],
    updated_at: str = "2026-01-01T12:00:00.000Z",
) -> dict:
    return {
        "id": ticket_id,
        "incident_code": "SF-FIRE",
        "label_ro": "Foc sau fum în terminal",
        "status": status,
        "joined_crew_ids": crew_ids,
        "updated_at": updated_at,
    }


class ProfileTests(unittest.TestCase):
    def test_events_profile_is_a_different_application(self) -> None:
        path = Path(__file__).resolve().parents[2] / "config" / "domains" / "events.json"
        profile = load_domain_config(str(path))
        self.assertEqual(profile.id, "events")
        self.assertEqual(profile.app_name, "CrowdGuard")
        self.assertEqual(profile.quorum.strategy, "fixed")
        self.assertEqual(profile.quorum.required_for(4), 1)
        self.assertEqual(profile.rewards.points_label, "CREDITE")


class QuorumPolicyTests(unittest.TestCase):
    def test_one_per_primary_department(self) -> None:
        policy = QuorumConfig(strategy="one_per_primary_department", minimum=1)
        self.assertEqual(policy.required_for(0), 1)
        self.assertEqual(policy.required_for(1), 1)
        self.assertEqual(policy.required_for(3), 3)

    def test_minimum(self) -> None:
        policy = QuorumConfig(
            strategy="one_per_primary_department",
            minimum=2,
        )
        self.assertEqual(policy.required_for(0), 2)
        self.assertEqual(policy.required_for(4), 4)

    def test_fixed(self) -> None:
        policy = QuorumConfig(strategy="fixed", fixed=1)
        self.assertEqual(policy.required_for(4), 1)


class RewardPolicyTests(unittest.TestCase):
    def setUp(self) -> None:
        self.domain = DomainConfig(
            rewards=RewardConfig(
                attended_points=2,
                resolved_bonus=10,
                denied_points=0,
                points_label="PUNCTE",
            )
        )
        self.tickets = [
            ticket("resolved", "resolved", ["crew-1"], "2026-01-01T12:00:00Z"),
            ticket("denied", "denied", ["crew-1"], "2026-01-01T11:00:00Z"),
            ticket(
                "active",
                "in_progress",
                ["crew-1"],
                "2026-01-01T10:00:00Z",
            ),
            ticket("other", "resolved", ["crew-2"]),
        ]

    def test_ledger_totals_and_order(self) -> None:
        ledger = self.domain.reward_ledger("crew-1", self.tickets)
        self.assertEqual(ledger["totalPoints"], 16)
        self.assertEqual(ledger["attendedCount"], 3)
        self.assertEqual(ledger["resolvedCount"], 1)
        self.assertEqual(ledger["inProgressCount"], 2)
        self.assertEqual(
            [entry["ticketId"] for entry in ledger["entries"]],
            ["resolved", "denied", "active"],
        )

    def test_other_crew_gets_empty_ledger(self) -> None:
        ledger = self.domain.reward_ledger("nobody", self.tickets)
        self.assertEqual(ledger["totalPoints"], 0)
        self.assertEqual(ledger["entries"], [])

    def test_custom_rules_are_data(self) -> None:
        domain = DomainConfig(
            rewards=RewardConfig(
                attended_points=1,
                resolved_bonus=5,
                denied_points=3,
                points_label="CREDITE",
            )
        )
        ledger = domain.reward_ledger("crew-1", self.tickets)
        self.assertEqual(ledger["totalPoints"], 11)
        self.assertEqual(ledger["pointsLabel"], "CREDITE")


if __name__ == "__main__":
    unittest.main()
