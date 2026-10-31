import unittest

from app.domain import DomainConfig, RewardConfig


def ticket(
    ticket_id: str,
    *,
    reporter_id: str = "reporter",
    status: str = "resolved",
    urgency: str = "high",
    joined: list[str] | None = None,
    voters: list[str] | None = None,
) -> dict:
    return {
        "id": ticket_id,
        "incident_code": "OP-MED",
        "label_ro": "Medical",
        "status": status,
        "urgency": urgency,
        "reporter_id": reporter_id,
        "joined_crew_ids": joined or [],
        "resolve_voter_ids": voters or [],
        "report_count": 1,
        "updated_at": "2026-01-01T12:00:00Z",
    }


class ReportingRewardTests(unittest.TestCase):
    def setUp(self) -> None:
        self.domain = DomainConfig(
            rewards=RewardConfig(
                report_points=2,
                attended_points=0,
                resolved_bonus=5,
                denied_points=0,
            )
        )

    def test_report_and_resolve_award_both_sources(self) -> None:
        tickets = [
            ticket(
                "both",
                reporter_id="crew-1",
                joined=["crew-1"],
                voters=["crew-1", "crew-2"],
            ),
            ticket("reported-only", reporter_id="crew-1", status="dispatched"),
        ]
        ledger = self.domain.reward_ledger("crew-1", tickets)
        self.assertEqual(ledger["reportedCount"], 2)
        self.assertEqual(ledger["attendedCount"], 1)
        self.assertEqual(ledger["resolvedCount"], 1)
        self.assertEqual(ledger["totalPoints"], 2 + 5 + 2)

    def test_self_report_self_resolve_non_dangerous_is_blocked(self) -> None:
        tickets = [
            ticket(
                "farm",
                reporter_id="crew-1",
                urgency="low",
                joined=["crew-1"],
                voters=["crew-1"],
                status="resolved",
            )
        ]
        ledger = self.domain.reward_ledger("crew-1", tickets)
        self.assertEqual(ledger["totalPoints"], 0)
        self.assertEqual(ledger["blockedSelfResolutions"], 1)
        self.assertEqual(ledger["entries"][0]["reason"], "self_resolution_blocked")

    def test_self_report_self_resolve_dangerous_still_counts(self) -> None:
        tickets = [
            ticket(
                "danger",
                reporter_id="crew-1",
                urgency="critical",
                joined=["crew-1"],
                voters=["crew-1"],
                status="resolved",
            )
        ]
        ledger = self.domain.reward_ledger("crew-1", tickets)
        self.assertEqual(ledger["totalPoints"], 2 + 5)
        self.assertEqual(ledger["blockedSelfResolutions"], 0)


if __name__ == "__main__":
    unittest.main()
