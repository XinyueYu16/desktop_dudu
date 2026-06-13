"""
DuDu DailyStatsManager — per-day reminder statistics.
Files: data/daily_stats/YYYY-MM-DD.json
"""

from __future__ import annotations

import json
from datetime import datetime, timedelta
from pathlib import Path

DATA_DIR = Path(__file__).resolve().parent / "data" / "daily_stats"


def _empty_day(date: str) -> dict:
    return {
        "date": date,
        "reminders": {
            "triggered": {},
            "acked": {},
        },
    }


class DailyStatsManager:
    """Track reminder trigger / ack counts per calendar day."""

    def __init__(self):
        self._current_date: str | None = None
        self._cache: dict | None = None

    @staticmethod
    def _today() -> str:
        return datetime.now().strftime("%Y-%m-%d")

    def _path(self, date: str) -> Path:
        return DATA_DIR / f"{date}.json"

    def _load(self, date: str) -> dict:
        path = self._path(date)
        try:
            with open(path, "r", encoding="utf-8") as f:
                data = json.load(f)
            if isinstance(data, dict):
                base = _empty_day(date)
                rem = data.get("reminders")
                if isinstance(rem, dict):
                    base["reminders"]["triggered"] = dict(rem.get("triggered") or {})
                    base["reminders"]["acked"] = dict(rem.get("acked") or {})
                return base
        except (FileNotFoundError, json.JSONDecodeError, OSError):
            pass
        return _empty_day(date)

    def _save(self, date: str, data: dict) -> None:
        DATA_DIR.mkdir(parents=True, exist_ok=True)
        path = self._path(date)
        with open(path, "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, indent=2)

    def _ensure_today(self) -> dict:
        today = self._today()
        if self._current_date != today or self._cache is None:
            self._current_date = today
            self._cache = self._load(today)
        return self._cache

    def record_trigger(self, reminder_id: str) -> None:
        data = self._ensure_today()
        triggered = data["reminders"]["triggered"]
        triggered[reminder_id] = int(triggered.get(reminder_id, 0)) + 1
        self._save(self._current_date, data)

    def record_ack(self, reminder_id: str) -> None:
        data = self._ensure_today()
        acked = data["reminders"]["acked"]
        acked[reminder_id] = int(acked.get(reminder_id, 0)) + 1
        self._save(self._current_date, data)

    def get_day(self, date: str) -> dict:
        return self._load(date)

    def build_yesterday_summary(self) -> dict | None:
        yesterday = (datetime.now() - timedelta(days=1)).strftime("%Y-%m-%d")
        stats = self._load(yesterday)
        triggered = stats.get("reminders", {}).get("triggered", {})
        acked = stats.get("reminders", {}).get("acked", {})
        if not triggered and not acked:
            return None

        lines: list[str] = []
        all_ids = sorted(set(triggered) | set(acked))
        for rid in all_ids:
            t = int(triggered.get(rid, 0))
            a = int(acked.get(rid, 0))
            lines.append(f"- {rid}: 触发 {t} 次，确认 {a} 次")

        summary_text = "[昨日提醒统计]\n" + "\n".join(lines)
        return {
            "date": yesterday,
            "summary": summary_text,
            "stats": stats,
        }
