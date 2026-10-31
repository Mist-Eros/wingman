"""Classification guards for the two demo-critical gaps: stab wounds and trapped people."""

from __future__ import annotations

import unittest

from app.ai import (
    Classification,
    apply_classification_guards,
    fallback_classify,
)
from app.taxonomy import get_taxonomy


def sc_behav() -> Classification:
    return Classification(
        incident_code="SC-BEHAV",
        urgency="high",
        confidence=0.9,
        rationale="persoană agresivă",
        ai_source="ollama",
    )


class ClassificationGuardTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.taxonomy = get_taxonomy()

    def test_stab_wound_overrides_security_with_medical(self) -> None:
        result = apply_classification_guards(
            self.taxonomy, "a fost înjunghiată o persoană", sc_behav()
        )
        self.assertEqual(result.incident_code, "OP-MED")
        self.assertEqual(
            list(self.taxonomy.require("OP-MED").primary_departments),
            ["medical"],
        )

    def test_blocked_person_routes_to_rescue(self) -> None:
        result = apply_classification_guards(
            self.taxonomy, "o persoană este blocată în lift", sc_behav()
        )
        self.assertEqual(result.incident_code, "OP-RESCUE")
        self.assertEqual(
            list(self.taxonomy.require("OP-RESCUE").primary_departments),
            ["fire_rescue"],
        )

    def test_person_in_danger_still_goes_to_security(self) -> None:
        result = apply_classification_guards(
            self.taxonomy, "o persoană este în pericol", sc_behav()
        )
        self.assertEqual(result.incident_code, "SC-BEHAV")

    def test_fallback_recognises_stab_and_trapped(self) -> None:
        stab = fallback_classify(self.taxonomy, "a fost înjunghiată o persoană")
        trapped = fallback_classify(self.taxonomy, "o persoană este blocată")
        self.assertEqual(stab.incident_code, "OP-MED")
        self.assertEqual(trapped.incident_code, "OP-RESCUE")


if __name__ == "__main__":
    unittest.main()
