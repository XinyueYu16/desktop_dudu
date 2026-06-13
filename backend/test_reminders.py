"""
Quick integration test for reminders scheduler and WebSocket handlers.
Does NOT persist settings — uses an isolated copy.
"""
import asyncio
import json
import time

from daily_stats import DailyStatsManager
from reminders import ReminderScheduler
from scheduler import AsyncScheduler
from settings import SettingsManager, _deep_copy, DEFAULTS


async def test_reminder_trigger():
    sent: list[tuple[str, dict]] = []

    async def send_fn(msg_type: str, payload: dict):
        sent.append((msg_type, payload))

    settings = SettingsManager()
    settings._data = _deep_copy(DEFAULTS)
    items = settings.get("reminders.items") or []
    items[0]["interval_minutes"] = 15
    items[0]["enabled"] = True
    settings._data["reminders"]["items"] = items

    scheduler = AsyncScheduler(tick_interval=0.5)
    daily_stats = DailyStatsManager()
    reminders = ReminderScheduler(scheduler, settings, daily_stats, send_fn)
    reminders.sync_from_settings()
    scheduler.reschedule("reminder:water", time.time() - 1)

    await scheduler.start()
    await asyncio.sleep(1.5)
    await scheduler.stop()

    triggers = [p for t, p in sent if t == "reminder.trigger"]
    assert triggers, f"expected reminder.trigger, got {sent}"
    print("trigger payload:", json.dumps(triggers[0], ensure_ascii=False))
    print("daily stats today:", daily_stats.get_day(daily_stats._today()))
    print("OK")


if __name__ == "__main__":
    asyncio.run(test_reminder_trigger())
