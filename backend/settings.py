"""
DuDu Settings Manager — JSON persistence for all configurable settings.
Reads/writes data/settings.json with sensible defaults.
"""

import json
from pathlib import Path

from prompts import DEFAULT_PROMPTS

SETTINGS_FILE = Path(__file__).resolve().parent / "data" / "settings.json"

MAX_REMINDERS = 5

_REMINDER_PRESETS = {
    "water": {
        "label": "喝水",
        "interval_minutes": 50,
        "animation": "lick_mouth",
        "bubble_text": "姐姐该喝水啦，喵~记得喝点水哦！",
    },
    "stretch": {
        "label": "提肛",
        "interval_minutes": 120,
        "animation": "wiggle_butt",
        "bubble_text": "站起来扭扭屁股~提肛时间到喵！",
    },
}


def default_reminder_items() -> list[dict]:
    items: list[dict] = []
    for preset_id, preset in _REMINDER_PRESETS.items():
        items.append(
            {
                "id": preset_id,
                "label": preset["label"],
                "interval_minutes": preset["interval_minutes"],
                "enabled": True,
                "next_at": None,
                "animation": preset["animation"],
                "bubble_text": preset["bubble_text"],
            }
        )
    return items


def migrate_reminders_schema(reminders: dict) -> dict:
    """Convert legacy water_/stretch_ fields to reminders.items[]."""
    if isinstance(reminders.get("items"), list) and not any(
        k in reminders
        for k in (
            "water_enabled",
            "stretch_enabled",
            "water_interval_minutes",
            "stretch_interval_minutes",
        )
    ):
        return {"items": reminders["items"]}

    items: list[dict] = []
    if reminders.get("water_enabled", True):
        preset = _REMINDER_PRESETS["water"]
        items.append(
            {
                "id": "water",
                "label": preset["label"],
                "interval_minutes": int(
                    reminders.get("water_interval_minutes") or preset["interval_minutes"]
                ),
                "enabled": True,
                "next_at": None,
                "animation": preset["animation"],
                "bubble_text": preset["bubble_text"],
            }
        )
    if reminders.get("stretch_enabled", True):
        preset = _REMINDER_PRESETS["stretch"]
        items.append(
            {
                "id": "stretch",
                "label": preset["label"],
                "interval_minutes": int(
                    reminders.get("stretch_interval_minutes") or preset["interval_minutes"]
                ),
                "enabled": True,
                "next_at": None,
                "animation": preset["animation"],
                "bubble_text": preset["bubble_text"],
            }
        )
    if not items:
        items = default_reminder_items()
    return {"items": items}

DEFAULTS = {
    "ui": {
        "scale_multiplier": 1.0,
    },
    "chat": {
        "model": "deepseek-v4-flash",
        "temperature": 0.8,
        "api_key": "",
        "api_base": "https://api.deepseek.com",
        "thinking_enabled": True,
        "use_memory": True,
        "record_memory": True,
    },
    "prompts": dict(DEFAULT_PROMPTS),
    "pomodoro": {
        "work_minutes": 25,
        "break_minutes": 5,
        "long_break_minutes": 15,
        "long_break_interval": 4,
    },
    "reminders": {
        "items": default_reminder_items(),
    },
    "stargazing": {
        "city": "上海",
        "latitude": 31.2304,
        "longitude": 121.4737,
        "timezone": "Asia/Shanghai",
    },
}


class SettingsManager:
    """Thread-safe settings with JSON file backing."""

    def __init__(self):
        self._data = None

    def _ensure_loaded(self):
        if self._data is not None:
            return
        self._data = _deep_copy(DEFAULTS)
        try:
            with open(SETTINGS_FILE, "r", encoding="utf-8") as f:
                loaded = json.load(f)
            _deep_merge(self._data, loaded)
            if _migrate_reminders(self._data):
                self._save()
            elif _sanitize_reminder_items(self._data):
                self._save()
        except (FileNotFoundError, json.JSONDecodeError):
            pass

    def get_all(self) -> dict:
        self._ensure_loaded()
        return _deep_copy(self._data)

    def get(self, key: str):
        """Dotted path: 'ui.scale_multiplier', 'chat.temperature', etc."""
        self._ensure_loaded()
        node = self._data
        for part in key.split("."):
            if isinstance(node, dict) and part in node:
                node = node[part]
            else:
                return None
        return node

    def set(self, key: str, value):
        """Set by dotted path. Persists to disk after every change."""
        self._ensure_loaded()
        parts = key.split(".")
        node = self._data
        for part in parts[:-1]:
            if part not in node:
                node[part] = {}
            node = node[part]
        node[parts[-1]] = value
        self._save()

    def set_bulk(self, updates: dict):
        """Apply multiple dotted-path updates at once. Persists once."""
        self._ensure_loaded()
        for key, value in updates.items():
            parts = key.split(".")
            node = self._data
            for part in parts[:-1]:
                if part not in node:
                    node[part] = {}
                node = node[part]
            node[parts[-1]] = value
        self._save()

    def _save(self):
        SETTINGS_FILE.parent.mkdir(parents=True, exist_ok=True)
        with open(SETTINGS_FILE, "w", encoding="utf-8") as f:
            json.dump(self._data, f, ensure_ascii=False, indent=2)


def _deep_copy(d: dict) -> dict:
    return json.loads(json.dumps(d))


def _deep_merge(base: dict, overlay: dict):
    for k, v in overlay.items():
        if k in base and isinstance(base[k], dict) and isinstance(v, dict):
            _deep_merge(base[k], v)
        else:
            base[k] = v


def _migrate_reminders(data: dict) -> bool:
    """Upgrade legacy water_/stretch_ reminder fields to items[]. Returns True if migrated."""
    reminders = data.get("reminders")
    if not isinstance(reminders, dict):
        data["reminders"] = {"items": default_reminder_items()}
        return True

    has_legacy = any(
        k in reminders
        for k in (
            "water_enabled",
            "stretch_enabled",
            "water_interval_minutes",
            "stretch_interval_minutes",
        )
    )
    has_items = isinstance(reminders.get("items"), list)

    if has_legacy:
        data["reminders"] = migrate_reminders_schema(reminders)
        return True
    if not has_items:
        data["reminders"] = {"items": default_reminder_items()}
        return True
    return False


def _sanitize_reminder_items(data: dict) -> bool:
    """Fix invalid reminder intervals (e.g. test leftovers) and stale next_at."""
    reminders = data.get("reminders")
    if not isinstance(reminders, dict):
        return False
    items = reminders.get("items")
    if not isinstance(items, list):
        return False

    changed = False
    for item in items:
        if not isinstance(item, dict):
            continue
        rid = str(item.get("id") or "")
        try:
            interval = int(item.get("interval_minutes") or 60)
        except (TypeError, ValueError):
            interval = 60
        if interval < 15:
            preset = _REMINDER_PRESETS.get(rid)
            item["interval_minutes"] = (
                int(preset["interval_minutes"]) if preset else 60
            )
            changed = True
    return changed
