"""Incident statistics for the admin views.

Pure function: takes the ticket snapshots and produces counters + a time series
for the selected period. Kept outside FastAPI so it is easy to test and reuse
from another UI (desktop dashboard, phone admin).
"""

from __future__ import annotations

from datetime import datetime, timedelta, timezone
from typing import Any, Iterable

PERIODS = ("day", "week", "month", "year")

_RO_WEEKDAYS = ("Lun", "Mar", "Mie", "Joi", "Vin", "Sâm", "Dum")
_RO_MONTHS = (
    "Ian",
    "Feb",
    "Mar",
    "Apr",
    "Mai",
    "Iun",
    "Iul",
    "Aug",
    "Sep",
    "Oct",
    "Noi",
    "Dec",
)


def _parse(value: Any) -> datetime | None:
    if not isinstance(value, str):
        return None
    try:
        return datetime.fromisoformat(value.replace("Z", "+00:00")).astimezone(
            timezone.utc
        )
    except ValueError:
        return None


def _bucket_config(
    period: str, now: datetime
) -> tuple[datetime, list[tuple[str, datetime, datetime]]]:
    """Return (window_start, [(label, start, end), ...]) in UTC."""
    if period == "day":
        end = now.replace(minute=0, second=0, microsecond=0) + timedelta(hours=1)
        start = end - timedelta(hours=24)
        buckets = []
        for i in range(24):
            b_start = start + timedelta(hours=i)
            buckets.append(
                (b_start.strftime("%H:00"), b_start, b_start + timedelta(hours=1))
            )
        return start, buckets
    if period == "week":
        end = now.replace(hour=0, minute=0, second=0, microsecond=0) + timedelta(days=1)
        start = end - timedelta(days=7)
        buckets = []
        for i in range(7):
            b_start = start + timedelta(days=i)
            buckets.append(
                (
                    _RO_WEEKDAYS[b_start.weekday()],
                    b_start,
                    b_start + timedelta(days=1),
                )
            )
        return start, buckets
    if period == "month":
        end = now.replace(hour=0, minute=0, second=0, microsecond=0) + timedelta(days=1)
        start = end - timedelta(days=30)
        buckets = []
        for i in range(30):
            b_start = start + timedelta(days=i)
            buckets.append(
                (
                    b_start.strftime("%d.%m"),
                    b_start,
                    b_start + timedelta(days=1),
                )
            )
        return start, buckets
    # year
    end = now.replace(day=1, hour=0, minute=0, second=0, microsecond=0) + timedelta(
        days=32
    )
    end = end.replace(day=1)
    start = end
    for _ in range(12):
        start = (start - timedelta(days=1)).replace(day=1)
    buckets = []
    cursor = start
    for _ in range(12):
        next_month = (cursor + timedelta(days=32)).replace(day=1)
        buckets.append((_RO_MONTHS[cursor.month - 1], cursor, next_month))
        cursor = next_month
    return start, buckets[-12:]


def build_stats(
    tickets: Iterable[dict[str, Any]],
    *,
    period: str = "week",
    now: datetime | None = None,
) -> dict[str, Any]:
    if period not in PERIODS:
        period = "week"
    current = (now or datetime.now(timezone.utc)).astimezone(timezone.utc)
    window_start, buckets = _bucket_config(period, current)
    window_end = buckets[-1][2] if buckets else current

    selected: list[dict[str, Any]] = []
    for ticket in tickets:
        created = _parse(ticket.get("created_at"))
        if created is not None and window_start <= created < window_end:
            selected.append(ticket)

    by_code: dict[str, dict[str, Any]] = {}
    by_urgency: dict[str, int] = {}
    by_department: dict[str, int] = {}
    status_counts: dict[str, int] = {}
    series = [0 for _ in buckets]
    series_handling = [[] for _ in buckets]
    handling_seconds: list[int] = []
    total_reports = 0

    for ticket in selected:
        code = str(ticket.get("incident_code") or "?")
        entry = by_code.setdefault(
            code,
            {
                "code": code,
                "labelRo": str(ticket.get("label_ro") or code),
                "category": str(ticket.get("category") or ""),
                "count": 0,
                "reports": 0,
            },
        )
        entry["count"] += 1
        reports = int(ticket.get("report_count") or 1)
        entry["reports"] += reports
        total_reports += reports

        urgency = str(ticket.get("urgency") or "unknown")
        by_urgency[urgency] = by_urgency.get(urgency, 0) + 1
        status = str(ticket.get("status") or "unknown")
        status_counts[status] = status_counts.get(status, 0) + 1
        for department in ticket.get("primary_departments") or []:
            key = str(department)
            by_department[key] = by_department.get(key, 0) + 1

        created = _parse(ticket.get("created_at"))
        resolved_at = _parse(ticket.get("resolved_at"))
        handling_duration: int | None = None
        if status == "resolved" and created is not None and resolved_at is not None:
            handling_duration = max(0, int((resolved_at - created).total_seconds()))
            handling_seconds.append(handling_duration)

        if created is not None:
            for index, (_, start, end) in enumerate(buckets):
                if start <= created < end:
                    series[index] += 1
                    if handling_duration is not None:
                        series_handling[index].append(handling_duration)
                    break

    average_handling = (
        round(sum(handling_seconds) / len(handling_seconds))
        if handling_seconds
        else None
    )

    return {
        "period": period,
        "generated_at": current.isoformat().replace("+00:00", "Z"),
        "total_tickets": len(selected),
        "total_reports": total_reports,
        "resolved": status_counts.get("resolved", 0),
        "denied": status_counts.get("denied", 0),
        "active": sum(
            status_counts.get(status, 0)
            for status in (
                "dispatched",
                "in_progress",
                "pending_override",
                "pending_resolution",
            )
        ),
        "by_code": sorted(
            by_code.values(), key=lambda item: (-item["count"], item["code"])
        ),
        "by_urgency": by_urgency,
        "by_department": [
            {"department": key, "count": value}
            for key, value in sorted(
                by_department.items(), key=lambda item: (-item[1], item[0])
            )
        ],
        "average_handling_seconds": average_handling,
        "handled_count": len(handling_seconds),
        "series": [
            {
                "label": label,
                "count": count,
                "handled_count": len(handling),
                "average_handling_seconds": (
                    round(sum(handling) / len(handling)) if handling else None
                ),
            }
            for (label, _, _), count, handling in zip(buckets, series, series_handling)
        ],
    }
