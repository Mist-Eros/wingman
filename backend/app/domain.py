"""Application profile + pluggable domain policies for the backend.

The JSON file is the same one bundled into the Flutter app
(`config/domains/airport.json`). Reuse Wingman for another venue by pointing
`DOMAIN_CONFIG` at a different profile and/ or swapping policy strategies — no
route code, store code or Flutter screen needs to change for supported options.

Supported quorum strategies:
  * ``one_per_primary_department`` — one responder per primary department
  * ``fixed`` — fixed number of responders

Rewards are computed by a pure policy from the ticket list. The app can render
the same ledger through its Dart RewardPolicy; the endpoint is available for
other clients/web dashboards.
"""

from __future__ import annotations

import json
import os
from dataclasses import dataclass, field
from functools import lru_cache
from pathlib import Path
from typing import Any, Iterable

from .config import BASE_DIR

DEFAULT_CONFIG_PATH = BASE_DIR.parent / "config" / "domains" / "airport.json"


@dataclass(frozen=True)
class QuorumConfig:
    strategy: str = "one_per_primary_department"
    minimum: int = 1
    fixed: int = 2

    def required_for(self, primary_department_count: int) -> int:
        if self.strategy == "fixed":
            return max(1, self.fixed)
        return max(self.minimum, primary_department_count)


@dataclass(frozen=True)
class RewardConfig:
    strategy: str = "rule_based"
    report_points: int = 2
    attended_points: int = 0
    resolved_bonus: int = 5
    denied_points: int = 0
    points_label: str = "PUNCTE"


@dataclass(frozen=True)
class NotificationConfig:
    roles: tuple[str, ...] = ("crew", "dispatcher")
    scope: str = "primary_departments"


@dataclass(frozen=True)
class DemoConfig:
    seed_tickets: int = 5
    reset_enabled: bool = True


@dataclass(frozen=True)
class DomainConfig:
    schema_version: int = 1
    id: str = "airport"
    app_name: str = "Wingman"
    tagline: str = "Airport incident response · demo"
    seed_color: str = "#1D4E89"
    features: dict[str, bool] = field(
        default_factory=lambda: {
            "rewards": True,
            "gpsMap": True,
            "photo": True,
            "accessibility": True,
            "history": True,
            "demoReset": True,
        }
    )
    quorum: QuorumConfig = field(default_factory=QuorumConfig)
    rewards: RewardConfig = field(default_factory=RewardConfig)
    notifications: NotificationConfig = field(default_factory=NotificationConfig)
    demo: DemoConfig = field(default_factory=DemoConfig)

    def reward_ledger(
        self,
        crew_id: str,
        tickets: Iterable[dict[str, Any]],
    ) -> dict[str, Any]:
        """Rewards for reporting + attending + resolving, with anti-farming."""
        relevant = [
            ticket
            for ticket in tickets
            if ticket.get("reporter_id") == crew_id
            or crew_id in (ticket.get("joined_crew_ids") or [])
        ]
        relevant.sort(key=lambda ticket: ticket.get("updated_at") or "", reverse=True)

        entries: list[dict[str, Any]] = []
        total = 0
        attended = 0
        reported = 0
        resolved = 0
        blocked = 0

        for ticket in relevant:
            is_reporter = ticket.get("reporter_id") == crew_id
            is_attending = crew_id in (ticket.get("joined_crew_ids") or [])
            is_resolved = ticket.get("status") == "resolved"
            resolved_alone = (
                is_resolved
                and len(ticket.get("resolve_voter_ids") or []) == 1
                and crew_id in (ticket.get("resolve_voter_ids") or [])
            )
            dangerous = ticket.get("urgency") in ("high", "critical")

            if is_reporter and is_attending and resolved_alone and not dangerous:
                blocked += 1
                entries.append(
                    {
                        "ticketId": ticket.get("id"),
                        "incidentCode": ticket.get("incident_code"),
                        "labelRo": ticket.get("label_ro"),
                        "status": ticket.get("status"),
                        "points": 0,
                        "reason": "self_resolution_blocked",
                        "updatedAt": ticket.get("updated_at"),
                    }
                )
                continue

            points = 0
            reasons: list[str] = []
            if is_reporter:
                points += self.rewards.report_points
                reported += 1
                reasons.append("reported")
            if is_attending:
                attended += 1
                # Join alone: 0. The 5 points require joined + resolved.
                if is_resolved:
                    points += self.rewards.resolved_bonus
                    resolved += 1
                    reasons.append("joined_solved")
                elif ticket.get("status") == "denied":
                    points += self.rewards.denied_points
                    reasons.append("denied")
                else:
                    reasons.append("joined_pending")
            elif is_resolved:
                # Reporter-only, resolved by someone else: report points only.
                reasons.append("reported_only")

            total += points
            entries.append(
                {
                    "ticketId": ticket.get("id"),
                    "incidentCode": ticket.get("incident_code"),
                    "labelRo": ticket.get("label_ro"),
                    "status": ticket.get("status"),
                    "points": points,
                    "reason": "+".join(reasons) or "reported",
                    "updatedAt": ticket.get("updated_at"),
                }
            )

        return {
            "crewId": crew_id,
            "totalPoints": total,
            "attendedCount": attended,
            "reportedCount": reported,
            "resolvedCount": resolved,
            "inProgressCount": attended - resolved,
            "blockedSelfResolutions": blocked,
            "pointsLabel": self.rewards.points_label,
            "entries": entries,
        }

    def to_public_dict(self) -> dict[str, Any]:
        """Safe subset for clients (no secrets; policies are intentional)."""
        return {
            "schemaVersion": self.schema_version,
            "id": self.id,
            "branding": {
                "appName": self.app_name,
                "tagline": self.tagline,
                "seedColor": self.seed_color,
            },
            "features": self.features,
            "quorum": {
                "strategy": self.quorum.strategy,
                "minimum": self.quorum.minimum,
                "fixed": self.quorum.fixed,
            },
            "rewards": {
                "strategy": self.rewards.strategy,
                "reportPoints": self.rewards.report_points,
                "attendedPoints": self.rewards.attended_points,
                "resolvedBonus": self.rewards.resolved_bonus,
                "deniedPoints": self.rewards.denied_points,
                "pointsLabel": self.rewards.points_label,
            },
            "notifications": {
                "roles": list(self.notifications.roles),
                "scope": self.notifications.scope,
            },
            "demo": {
                "seedTickets": self.demo.seed_tickets,
                "resetEnabled": self.demo.reset_enabled,
            },
        }


def _load_dict(path: Path) -> dict[str, Any]:
    with path.open(encoding="utf-8") as handle:
        data = json.load(handle)
    if not isinstance(data, dict):
        raise ValueError(f"{path}: domain config root must be an object")
    return data


def _resolve_path(raw: str | None) -> Path:
    if not raw:
        return DEFAULT_CONFIG_PATH
    path = Path(raw)
    if path.is_absolute():
        return path
    return BASE_DIR.parent / path


def _build(raw: dict[str, Any]) -> DomainConfig:
    branding = raw.get("branding") or {}
    features = raw.get("features") or {}
    quorum = raw.get("quorum") or {}
    rewards = raw.get("rewards") or {}
    notifications = raw.get("notifications") or {}
    demo = raw.get("demo") or {}

    def int_value(value: Any, fallback: int) -> int:
        try:
            return int(value)
        except (TypeError, ValueError):
            return fallback

    rules = tuple(str(role).lower() for role in notifications.get("roles") or [])
    return DomainConfig(
        schema_version=int_value(raw.get("schemaVersion"), 1),
        id=str(raw.get("id") or "airport"),
        app_name=str(branding.get("appName") or "Wingman"),
        tagline=str(branding.get("tagline") or "Airport incident response · demo"),
        seed_color=str(branding.get("seedColor") or "#1D4E89"),
        features={str(key): bool(value) for key, value in features.items()},
        quorum=QuorumConfig(
            strategy=str(quorum.get("strategy") or "one_per_primary_department"),
            minimum=int_value(quorum.get("minimum"), 1),
            fixed=int_value(quorum.get("fixed"), 2),
        ),
        rewards=RewardConfig(
            strategy=str(rewards.get("strategy") or "rule_based"),
            report_points=int_value(rewards.get("reportPoints"), 3),
            attended_points=int_value(rewards.get("attendedPoints"), 2),
            resolved_bonus=int_value(rewards.get("resolvedBonus"), 10),
            denied_points=int_value(rewards.get("deniedPoints"), 0),
            points_label=str(rewards.get("pointsLabel") or "PUNCTE"),
        ),
        notifications=NotificationConfig(
            roles=rules or ("crew", "dispatcher"),
            scope=str(notifications.get("scope") or "primary_departments"),
        ),
        demo=DemoConfig(
            seed_tickets=int_value(demo.get("seedTickets"), 5),
            reset_enabled=bool(demo.get("resetEnabled", True)),
        ),
    )


@lru_cache(maxsize=4)
def load_domain_config(path: str | None = None) -> DomainConfig:
    """Loads once per path. Missing/invalid config falls back to airport."""

    resolved = _resolve_path(path or os.getenv("DOMAIN_CONFIG"))
    try:
        return _build(_load_dict(resolved))
    except (OSError, ValueError, json.JSONDecodeError) as error:
        import logging

        logging.getLogger("airport.domain").warning(
            "Could not load domain config %s (%s); using default airport profile",
            resolved,
            error,
        )
        return DomainConfig()


def clear_domain_cache() -> None:
    load_domain_config.cache_clear()
