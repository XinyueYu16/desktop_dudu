"""
DuDu Inventory — loot table and stacked item storage.
Item catalog: data/items.json (inspired by animal-island-ui icons).
User inventory: data/inventory.json
"""

from __future__ import annotations

import json
import random
import tempfile
from pathlib import Path
from typing import Any

ITEMS_FILE = Path(__file__).resolve().parent / "data" / "items.json"
INVENTORY_FILE = Path(__file__).resolve().parent / "data" / "inventory.json"


class LootTable:
    """Weighted random item roll."""

    def __init__(self, catalog_path: Path | None = None):
        self._catalog_path = catalog_path or ITEMS_FILE
        self._catalog = self._load_catalog()

    def _load_catalog(self) -> list[dict]:
        if not self._catalog_path.exists():
            return []
        try:
            with open(self._catalog_path, "r", encoding="utf-8") as f:
                data = json.load(f)
            if isinstance(data, list):
                return [i for i in data if isinstance(i, dict) and i.get("id")]
        except (json.JSONDecodeError, IOError):
            pass
        return []

    def get_catalog(self) -> list[dict]:
        return list(self._catalog)

    def roll(self) -> dict | None:
        if not self._catalog:
            return None
        weights = [max(1, int(i.get("weight") or 1)) for i in self._catalog]
        choice = random.choices(self._catalog, weights=weights, k=1)[0]
        return dict(choice)


class InventoryManager:
    """Persist stacked items: [{id, count}]."""

    def __init__(
        self,
        path: Path | None = None,
        loot: LootTable | None = None,
    ):
        self._path = path or INVENTORY_FILE
        self._loot = loot or LootTable()
        self._path.parent.mkdir(parents=True, exist_ok=True)

    def _read(self) -> list[dict]:
        if not self._path.exists():
            return []
        try:
            with open(self._path, "r", encoding="utf-8") as f:
                data = json.load(f)
            if not isinstance(data, list):
                return []
            out: list[dict] = []
            for entry in data:
                if not isinstance(entry, dict):
                    continue
                iid = str(entry.get("id") or "").strip()
                if not iid:
                    continue
                try:
                    count = int(entry.get("count") or 1)
                except (TypeError, ValueError):
                    count = 1
                if count > 0:
                    out.append({"id": iid, "count": count})
            return out
        except (json.JSONDecodeError, IOError):
            return []

    def _write(self, items: list[dict]) -> None:
        fd, tmp = tempfile.mkstemp(dir=str(self._path.parent), suffix=".tmp")
        try:
            with open(fd, "w", encoding="utf-8") as f:
                json.dump(items, f, ensure_ascii=False, indent=2)
            Path(tmp).replace(self._path)
        except Exception:
            Path(tmp).unlink(missing_ok=True)
            raise

    def _catalog_by_id(self) -> dict[str, dict]:
        return {str(i["id"]): i for i in self._loot.get_catalog()}

    def get_items_enriched(self) -> list[dict]:
        catalog = self._catalog_by_id()
        result: list[dict] = []
        for entry in self._read():
            meta = catalog.get(entry["id"], {})
            result.append(
                {
                    "id": entry["id"],
                    "count": entry["count"],
                    "name": meta.get("name", entry["id"]),
                    "icon": meta.get("icon", ""),
                    "emoji": meta.get("emoji", "📦"),
                    "rarity": meta.get("rarity", "common"),
                }
            )
        return result

    def add_item(self, item_id: str, count: int = 1) -> dict | None:
        iid = str(item_id or "").strip()
        if not iid or count <= 0:
            return None
        items = self._read()
        found = False
        for entry in items:
            if entry["id"] == iid:
                entry["count"] = int(entry["count"]) + count
                found = True
                break
        if not found:
            items.append({"id": iid, "count": count})
        self._write(items)
        catalog = self._catalog_by_id()
        meta = catalog.get(iid, {})
        return {
            "id": iid,
            "count": count,
            "name": meta.get("name", iid),
            "icon": meta.get("icon", ""),
            "emoji": meta.get("emoji", "📦"),
            "rarity": meta.get("rarity", "common"),
        }

    def roll_and_add(self) -> dict | None:
        rolled = self._loot.roll()
        if rolled is None:
            return None
        return self.add_item(str(rolled["id"]), 1)
