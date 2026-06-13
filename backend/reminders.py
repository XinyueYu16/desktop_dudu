"""
DuDu ReminderScheduler — recurring fixed-text reminder bubbles.
Wraps AsyncScheduler; persists items in settings.reminders.items[].
"""

from __future__ import annotations

import time
import uuid
from collections.abc import Awaitable, Callable
from typing import Any

from daily_stats import DailyStatsManager
from scheduler import AsyncScheduler
from settings import SettingsManager, default_reminder_items

MAX_REMINDERS = 5

PRESETS: dict[str, dict[str, Any]] = {}

GENERIC_PRESET = {
    "animation": "happy",
    "bubble_text": "嘟嘟提醒你一下喵~",
}

SendFn = Callable[[str, dict], Awaitable[None]]


def _new_id() -> str:
    return uuid.uuid4().hex[:8]


def default_items() -> list[dict]:
    return default_reminder_items()


def _normalize_item(raw: dict, *, preserve_next_at: bool = True) -> dict | None:
    if not isinstance(raw, dict):
        return None
    item_id = str(raw.get("id") or "").strip() or _new_id()
    label = str(raw.get("label") or "提醒").strip() or "提醒"
    try:
        interval = int(raw.get("interval_minutes") or 60)
    except (TypeError, ValueError):
        interval = 60
    interval = max(15, min(interval, 24 * 60))
    enabled = bool(raw.get("enabled", True))
    animation = str(raw.get("animation") or GENERIC_PRESET["animation"]).strip()
    bubble_text = str(raw.get("bubble_text") or GENERIC_PRESET["bubble_text"]).strip()
    next_at = raw.get("next_at") if preserve_next_at else None
    if next_at is not None:
        try:
            next_at = float(next_at)
        except (TypeError, ValueError):
            next_at = None
    return {
        "id": item_id,
        "label": label,
        "interval_minutes": interval,
        "enabled": enabled,
        "next_at": next_at,
        "animation": animation,
        "bubble_text": bubble_text,
    }


class ReminderScheduler:
    """Schedule and fire fixed-text reminder bubbles."""

    def __init__(
        self,
        scheduler: AsyncScheduler,
        settings: SettingsManager,
        daily_stats: DailyStatsManager,
        send_fn: SendFn,
    ):
        self._scheduler = scheduler
        self._settings = settings
        self._daily_stats = daily_stats
        self._send = send_fn
        self._firing: set[str] = set()

    def get_items(self) -> list[dict]:
        raw = self._settings.get("reminders.items") or []
        if not isinstance(raw, list):
            raw = default_items()
        items: list[dict] = []
        for entry in raw:
            norm = _normalize_item(entry)
            if norm:
                items.append(norm)
        return items[:MAX_REMINDERS]

    def _save_items(self, items: list[dict]) -> None:
        self._settings.set("reminders.items", items[:MAX_REMINDERS])

    def _compute_next_at(self, item: dict, *, force_reset: bool = False) -> float:
        now = time.time()
        next_at = item.get("next_at")
        if not force_reset and next_at is not None:
            try:
                val = float(next_at)
                if val > now:
                    return val
            except (TypeError, ValueError):
                pass
        interval = int(item.get("interval_minutes") or 60)
        return now + interval * 60

    def _min_gap_seconds(self, item: dict) -> float:
        interval = int(item.get("interval_minutes") or 60)
        return max(60.0, float(interval) * 60.0)

    def sync_from_settings(self) -> None:
        """Register enabled reminders with the shared scheduler."""
        for job_id in list(self._scheduler._jobs.keys()):
            if job_id.startswith("reminder:"):
                self._scheduler.cancel(job_id)

        for item in self.get_items():
            if not item.get("enabled"):
                continue
            next_at = self._compute_next_at(item)
            item["next_at"] = next_at
            job_id = f"reminder:{item['id']}"
            self._scheduler.register(
                job_id,
                next_at,
                self._make_callback(item["id"]),
            )
        self._persist_next_at_times(force=True)

    def _persist_next_at_times(self, *, force: bool = False) -> None:
        items = self.get_items()
        changed = False
        for item in items:
            job_id = f"reminder:{item['id']}"
            na = self._scheduler.next_at(job_id)
            if na is not None and (force or item.get("next_at") != na):
                item["next_at"] = na
                changed = True
        if changed:
            self._save_items(items)

    def _make_callback(self, reminder_id: str):
        async def _cb() -> None:
            await self._on_trigger(reminder_id)

        return _cb

    async def _on_trigger(self, reminder_id: str) -> None:
        if reminder_id in self._firing:
            return
        self._firing.add(reminder_id)
        try:
            await self._do_trigger(reminder_id)
        finally:
            self._firing.discard(reminder_id)

    async def _do_trigger(self, reminder_id: str) -> None:
        items = self.get_items()
        item = next((i for i in items if i["id"] == reminder_id), None)
        if item is None or not item.get("enabled"):
            self._scheduler.cancel(f"reminder:{reminder_id}")
            return

        # Reschedule before send so a slow/failed push cannot re-fire on next tick.
        next_at = time.time() + self._min_gap_seconds(item)
        item["next_at"] = next_at
        self._save_items(items)
        self._scheduler.reschedule(f"reminder:{reminder_id}", next_at)

        self._daily_stats.record_trigger(reminder_id)

        await self._send(
            "reminder.trigger",
            {
                "id": reminder_id,
                "label": item.get("label", ""),
                "bubble_text": item.get("bubble_text", GENERIC_PRESET["bubble_text"]),
                "animation": item.get("animation", GENERIC_PRESET["animation"]),
            },
        )
        await self._send("reminders.data", {"items": self.get_items()})

    def set_items(self, raw_items: list) -> list[dict]:
        if not isinstance(raw_items, list):
            raw_items = []
        existing = {i["id"]: i for i in self.get_items()}
        normalized: list[dict] = []
        for raw in raw_items[:MAX_REMINDERS]:
            norm = _normalize_item(raw, preserve_next_at=True)
            if norm is None:
                continue
            prev = existing.get(norm["id"])
            if prev is not None:
                if norm.get("next_at") is None:
                    norm["next_at"] = prev.get("next_at")
            if norm.get("enabled"):
                norm["next_at"] = self._compute_next_at(norm, force_reset=True)
            else:
                norm["next_at"] = None
            normalized.append(norm)

        if not normalized:
            normalized = default_items()
            for item in normalized:
                item["next_at"] = self._compute_next_at(item, force_reset=True)

        self._save_items(normalized)
        self.sync_from_settings()
        return self.get_items()

    async def handle_ack(self, reminder_id: str) -> None:
        rid = str(reminder_id or "").strip()
        if rid:
            self._daily_stats.record_ack(rid)
