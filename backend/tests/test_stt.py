"""Unit tests for safe LLM transcript correction (no server/model needed)."""

from __future__ import annotations

import unittest

from app.stt import merge_corrected_transcript


def word(text: str, probability: float) -> dict:
    return {"text": text, "probability": probability, "start": 0.0, "end": 0.0}


class CorrectionMergeTests(unittest.TestCase):
    def test_fixes_low_confidence_word_but_keeps_high_confidence_words(self) -> None:
        raw = "am o pata de ulei langa poarta trei"
        words = tuple(
            [
                word("am", 0.95),
                word("o", 0.98),
                word("pata", 0.42),
                word("de", 0.97),
                word("ulei", 0.93),
                word("langa", 0.91),
                word("poarta", 0.88),
                word("trei", 0.86),
            ]
        )
        corrected = "am o pată de ulei la poarta 3"
        merged_text, merged_words = merge_corrected_transcript(raw, words, corrected)
        self.assertIn("pată", merged_text)
        self.assertIn("langa", merged_text, "high-confidence word must stay")
        self.assertIn("trei", merged_text, "numbers must not be rewritten")
        self.assertEqual(len(merged_words), len(merged_text.split()))

    def test_rejects_added_words(self) -> None:
        raw = "fum la poarta"
        words = tuple(word(token, 0.9) for token in raw.split())
        merged_text, _ = merge_corrected_transcript(
            raw, words, "fum dens la poarta 12"
        )
        self.assertEqual(merged_text, raw)

    def test_diacritic_only_fix_is_allowed_for_high_confidence(self) -> None:
        raw = "pata de ulei"
        words = tuple(word(token, 0.95) for token in raw.split())
        merged_text, merged_words = merge_corrected_transcript(
            raw, words, "pată de ulei"
        )
        self.assertEqual(merged_text, "pată de ulei")
        self.assertAlmostEqual(merged_words[0]["probability"], 0.95)


if __name__ == "__main__":
    unittest.main()
