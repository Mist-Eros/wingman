"""Prepared demo fixture must stay aligned with the UI contract."""

from __future__ import annotations

import unittest

from app.demo_data import DEMO_CASES


class DemoDataTests(unittest.TestCase):
    def test_prepared_cases_have_expected_urgency_distribution(self) -> None:
        codes = [case["code"] for case in DEMO_CASES]
        self.assertEqual(len(codes), 5)
        self.assertEqual(codes.count("SF-FIRE"), 1)
        self.assertEqual(codes.count("SF-SPILL"), 1)
        self.assertEqual(codes.count("SC-BAG"), 1)
        self.assertEqual(codes.count("SC-ITEM"), 1)
        self.assertEqual(codes.count("OP-OTHER"), 1)
        medium = next(case for case in DEMO_CASES if case["code"] == "SF-SPILL")
        self.assertEqual(medium.get("quorum_override"), 1)


if __name__ == "__main__":
    unittest.main()
