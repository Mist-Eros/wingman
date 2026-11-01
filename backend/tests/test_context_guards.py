"""Context guards for the ambiguous phrases the small local LLM missed."""

from __future__ import annotations

import unittest

from app.ai import Classification, apply_classification_guards
from app.taxonomy import get_taxonomy


class ContextGuardTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.taxonomy = get_taxonomy()

    def test_ambiguous_phrases_route_to_expected_codes(self) -> None:
        cases = (
            ("miroase a ars în zona de bagaje", "SF-FIRE"),
            ("liftul e blocat cu cineva în el", "OP-RESCUE"),
            ("s-a oprit netul la check-in", "OP-IT"),
            ("cineva a sărit gardul pe platformă", "SC-ACCESS"),
            ("pasager rău, nu răspunde", "OP-MED"),
            ("ceva pe pistă, nu știu ce", "SF-FOD"),
            ("scaun rupt la poarta 4", "OP-OTHER"),
            ("e o pată mare de ulei lângă avion", "SF-SPILL"),
        )
        for transcript, expected in cases:
            with self.subTest(transcript=transcript):
                original = Classification(
                    incident_code="OP-OTHER",
                    urgency="low",
                    confidence=0.95,
                    rationale="model greșit",
                    ai_source="ollama",
                )
                result = apply_classification_guards(
                    self.taxonomy, transcript, original
                )
                self.assertEqual(result.incident_code, expected)
                self.assertEqual(
                    result.urgency,
                    self.taxonomy.require(expected).urgency,
                    "guard must not lower the ticket urgency",
                )


if __name__ == "__main__":
    unittest.main()
