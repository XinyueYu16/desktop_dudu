"""
DuDu TodoStore — bullet todo list with optional one-shot AI reminders.
"""

from __future__ import annotations

import json
import re
import tempfile
import time
import uuid
from collections.abc import Awaitable, Callable
from datetime import datetime
from pathlib import Path
from typing import Any

try:
    from zoneinfo import ZoneInfo
except ImportError:
    ZoneInfo = None  # type: ignore

from scheduler import AsyncScheduler

TODOS_FILE = Path(__file__).resolve().parent / "data" / "todos.json"
CST = ZoneInfo("Asia/Shanghai") if ZoneInfo is not None else None

SendFn = Callable[[str, dict], Awaitable[None]]
ChatFn = Callable[..., Awaitable[None]]

_REMIND_RE = re.compile(
    r"^(\d{2,4})[/\-](\d{1,2})[/\-](\d{1,2})\s+(\d{1,2}):(\d{2})$"
)


def _new_id() -> str:
    return uuid.uuid4().hex[:8]


def _now_iso() -> str:
    return datetime.now().strftime("%Y-%m-%d %H:%M:%S")


def _parse_remind_at_text(text: str) -> float | None:
    """Parse remind_at_text as Asia/Shanghai wall time."""
    raw = str(text or "").strip()
    if not raw:
        return None
    m = _REMIND_RE.match(raw)
    if not m:
        return None
    year, month, day, hour, minute = (int(m.group(i)) for i in range(1, 6))
    if year < 100:
        year += 2000
    if month < 1 or month > 12 or day < 1 or day > 31:
        return None
    if hour < 0 or hour > 23 or minute < 0 or minute > 59:
        return None
    try:
        if CST is not None:
            dt = datetime(year, month, day, hour, minute, tzinfo=CST)
            return float(dt.timestamp())
        # Fallback: treat as UTC+8 fixed offset
        from datetime import timezone, timedelta

        dt = datetime(
            year, month, day, hour, minute, tzinfo=timezone(timedelta(hours=8))
        )
        return float(dt.timestamp())
    except (ValueError, OSError):
        return None


def _format_remind_at_text(unix_ts: float) -> str:
    try:
        if CST is not None:
            dt = datetime.fromtimestamp(unix_ts, tz=CST)
        else:
            from datetime import timezone, timedelta

            dt = datetime.fromtimestamp(
                unix_ts, tz=timezone(timedelta(hours=8))
            )
        return dt.strftime("%Y/%m/%d %H:%M")
    except (ValueError, OSError):
        return ""


def _normalize_todo(raw: dict) -> dict | None:
    if not isinstance(raw, dict):
        return None
    text = str(raw.get("text") or "").strip()
    if not text:
        return None
    todo_id = str(raw.get("id") or "").strip() or _new_id()
    done = bool(raw.get("done", False))
    remind_at = raw.get("remind_at")
    if remind_at is not None:
        try:
            remind_at = float(remind_at)
            if remind_at <= 0:
                remind_at = None
        except (TypeError, ValueError):
            remind_at = None
    if done:
        remind_at = None
    created_at = str(raw.get("created_at") or _now_iso())
    remind_at_text = str(raw.get("remind_at_text") or "").strip()
    if not done and remind_at_text:
        parsed = _parse_remind_at_text(remind_at_text)
        if parsed is not None:
            remind_at = parsed
            remind_at_text = _format_remind_at_text(parsed)
    elif remind_at is not None and not remind_at_text:
        remind_at_text = _format_remind_at_text(float(remind_at))
    return {
        "id": todo_id,
        "text": text,
        "done": done,
        "remind_at": remind_at,
        "remind_at_text": remind_at_text,
        "created_at": created_at,
    }


class TodoStore:
    """CRUD for todos.json."""

    def __init__(self, path: Path | None = None):
        self._path = path or TODOS_FILE
        self._path.parent.mkdir(parents=True, exist_ok=True)

    def _read(self) -> list[dict]:
        if not self._path.exists():
            return []
        try:
            with open(self._path, "r", encoding="utf-8") as f:
                data = json.load(f)
            if not isinstance(data, list):
                return []
            items: list[dict] = []
            for entry in data:
                norm = _normalize_todo(entry)
                if norm:
                    items.append(norm)
            return items
        except (json.JSONDecodeError, IOError):
            return []

    def _write(self, items: list[dict]) -> None:
        self._path.parent.mkdir(parents=True, exist_ok=True)
        fd, tmp = tempfile.mkstemp(dir=str(self._path.parent), suffix=".tmp")
        try:
            with open(fd, "w", encoding="utf-8") as f:
                json.dump(items, f, ensure_ascii=False, indent=2)
            Path(tmp).replace(self._path)
        except Exception:
            Path(tmp).unlink(missing_ok=True)
            raise

    def get_all(self) -> list[dict]:
        return self._read()

    def repair_remind_times(self) -> bool:
        """Re-parse remind_at_text into remind_at (Asia/Shanghai). Returns True if changed."""
        items = self._read()
        changed = False
        for i, item in enumerate(items):
            if item.get("done"):
                continue
            text = str(item.get("remind_at_text") or "").strip()
            if not text:
                continue
            parsed = _parse_remind_at_text(text)
            if parsed is None:
                continue
            norm_text = _format_remind_at_text(parsed)
            if item.get("remind_at") != parsed or item.get("remind_at_text") != norm_text:
                item["remind_at"] = parsed
                item["remind_at_text"] = norm_text
                items[i] = item
                changed = True
        if changed:
            self._write(items)
        return changed

    def replace_all(self, raw_items: list) -> list[dict]:
        if not isinstance(raw_items, list):
            raw_items = []
        normalized: list[dict] = []
        for raw in raw_items:
            norm = _normalize_todo(raw)
            if norm:
                normalized.append(norm)
        self._write(normalized)
        return self.get_all()

    def add(self, text: str, remind_at: float | None = None) -> dict:
        item = _normalize_todo(
            {
                "id": _new_id(),
                "text": text,
                "done": False,
                "remind_at": remind_at,
                "created_at": _now_iso(),
            }
        )
        if item is None:
            raise ValueError("empty todo text")
        items = self._read()
        items.append(item)
        self._write(items)
        return item

    def update(self, todo_id: str, **fields: Any) -> dict | None:
        tid = str(todo_id or "").strip()
        if not tid:
            return None
        items = self._read()
        for i, item in enumerate(items):
            if item["id"] != tid:
                continue
            merged = dict(item)
            merged.update(fields)
            if fields.get("remind_at") is None and "remind_at_text" not in fields:
                merged["remind_at_text"] = ""
            norm = _normalize_todo(merged)
            if norm is None:
                return None
            items[i] = norm
            self._write(items)
            return norm
        return None

    def delete(self, todo_id: str) -> bool:
        tid = str(todo_id or "").strip()
        if not tid:
            return False
        items = self._read()
        kept = [t for t in items if t["id"] != tid]
        if len(kept) == len(items):
            return False
        self._write(kept)
        return True


class TodoScheduler:
    """Schedule one-shot todo reminders via shared AsyncScheduler."""

    def __init__(
        self,
        scheduler: AsyncScheduler,
        store: TodoStore,
        send_fn: SendFn,
        chat_fn: ChatFn,
    ):
        self._scheduler = scheduler
        self._store = store
        self._send = send_fn
        self._chat = chat_fn
        self._firing: set[str] = set()

    def sync_all(self) -> None:
        for job_id in list(self._scheduler._jobs.keys()):
            if job_id.startswith("todo:"):
                self._scheduler.cancel(job_id)
        now = time.time()
        for item in self._store.get_all():
            if item.get("done"):
                continue
            remind_at = item.get("remind_at")
            if remind_at is None:
                continue
            try:
                at = float(remind_at)
            except (TypeError, ValueError):
                continue
            if at <= now:
                at = now + 1.0
            job_id = f"todo:{item['id']}"
            self._scheduler.register(job_id, at, self._make_callback(item["id"]))

    def _make_callback(self, todo_id: str):
        async def _cb() -> None:
            await self._on_trigger(todo_id)

        return _cb

    async def _on_trigger(self, todo_id: str) -> None:
        if todo_id in self._firing:
            return
        self._firing.add(todo_id)
        try:
            await self._do_trigger(todo_id)
        finally:
            self._firing.discard(todo_id)

    async def _do_trigger(self, todo_id: str) -> None:
        self._scheduler.cancel(f"todo:{todo_id}")
        item = next((t for t in self._store.get_all() if t["id"] == todo_id), None)
        if item is None or item.get("done"):
            return

        # Clear remind_at so it won't fire again
        self._store.update(todo_id, remind_at=None, remind_at_text="")

        text = str(item.get("text", ""))
        await self._send(
            "todo.remind",
            {"id": todo_id, "text": text},
        )
        prompt = f"[TODO提醒] 到时间了，提醒姐姐完成这件事：{text}"
        await self._chat(
            prompt,
            "todo_remind",
            thinking=False,
            use_memory=False,
            record_memory=False,
        )
        await self._send("todos.data", {"items": self._store.get_all()})

    def on_todos_changed(self) -> None:
        self.sync_all()
