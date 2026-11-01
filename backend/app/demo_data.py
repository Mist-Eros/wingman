"""Deterministic prepared demo state.

Used by `POST /api/demo/reset`; keeps the app and the backend seed aligned.
Five cases: 1 low, 1 medium, 2 high, 1 critical. Only SF-FIRE requires two
responders; the medium case pins quorum 1 for the guided demo.
"""

from __future__ import annotations

from typing import Any

DEMO_CASES: tuple[dict[str, Any], ...] = (
    {
        "code": "OP-OTHER",
        "transcript": "Coada de la control este lungă, dar nu e nimic periculos.",
        "reporter_id": "seed-reporter-1",
        "reporter_name": "Andrei P.",
        "location": {"terminal": "T1", "zone": "Control securitate"},
    },
    {
        "code": "SF-SPILL",
        "transcript": "S-a vărsat un lichid pe jos lângă poarta 3.",
        "reporter_id": "seed-reporter-2",
        "reporter_name": "Ioana M.",
        "location": {"terminal": "T1", "zone": "Poarta 3"},
        "quorum_override": 1,
    },
    {
        "code": "SC-BAG",
        "transcript": "Bagaj fără proprietar lângă banda de bagaje 3.",
        "reporter_id": "seed-reporter-3",
        "reporter_name": "Mihai D.",
        "location": {"terminal": "T2", "zone": "Banda bagaje 3"},
    },
    {
        "code": "SC-ITEM",
        "transcript": "Obiect interzis găsit la controlul de securitate.",
        "reporter_id": "seed-reporter-4",
        "reporter_name": "Elena V.",
        "location": {"terminal": "T1", "zone": "Control securitate"},
    },
    {
        "code": "SF-FIRE",
        "transcript": "Fum dens lângă poarta 12, în terminalul 1.",
        "reporter_id": "seed-reporter-5",
        "reporter_name": "Furtuna-Cola Andrei-Alexandru",
        "location": {"terminal": "T1", "zone": "Poarta 12"},
    },
)
