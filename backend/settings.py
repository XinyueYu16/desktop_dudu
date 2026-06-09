"""
DuDu Settings Manager — JSON persistence for all configurable settings.
Reads/writes data/settings.json with sensible defaults.
"""

import json
from pathlib import Path

SETTINGS_FILE = Path(__file__).resolve().parent / "data" / "settings.json"

DEFAULTS = {
    "ui": {
        "scale_multiplier": 1.0,
    },
    "chat": {
        "model": "deepseek-chat",
        "temperature": 0.8,
    },
    "pomodoro": {
        "work_minutes": 25,
        "break_minutes": 5,
        "long_break_minutes": 15,
        "long_break_interval": 4,
    },
    "reminders": {
        "water_enabled": True,
        "water_interval_minutes": 60,
        "stretch_enabled": True,
        "stretch_interval_minutes": 90,
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
