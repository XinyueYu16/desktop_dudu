"""
DuDu Memory — JSONL persistence (simplified from Nero MemoryManager).
Full history in data/memory/YYYY-MM-DD.jsonl, one JSON object per line.
"""
import json
import threading
import tempfile
from datetime import datetime
from pathlib import Path

_lock = threading.RLock()

DEFAULT_DATA_DIR = Path(__file__).resolve().parent / "data"
MEMORY_DIR_NAME = "memory"


class MemoryManager:
    """Persistent chat memory backed by date-separated JSONL files."""

    def __init__(self, data_root: Path | None = None):
        root = data_root or DEFAULT_DATA_DIR
        self._memory_dir = root / MEMORY_DIR_NAME
        self._memory_dir.mkdir(parents=True, exist_ok=True)

    # ── path helpers ──

    def _day_key(self, ts: str) -> str:
        if len(ts) >= 10 and ts[4] == "-" and ts[7] == "-":
            return ts[:10]
        return datetime.now().strftime("%Y-%m-%d")

    def _path_for_day(self, day: str) -> Path:
        return self._memory_dir / f"{day}.jsonl"

    def _all_day_paths(self) -> list[Path]:
        if not self._memory_dir.is_dir():
            return []
        return sorted(self._memory_dir.glob("*.jsonl"))

    # ── low-level read/write ──

    @staticmethod
    def _read_jsonl(path: Path) -> list[dict]:
        entries: list[dict] = []
        if not path.exists():
            return entries
        try:
            with open(path, "r", encoding="utf-8") as f:
                for line in f:
                    line = line.strip()
                    if not line:
                        continue
                    try:
                        obj = json.loads(line)
                        if isinstance(obj, dict):
                            entries.append(obj)
                    except json.JSONDecodeError:
                        continue
        except IOError:
            pass
        return entries

    @staticmethod
    def _write_jsonl(path: Path, entries: list[dict]) -> None:
        """Atomic write via tempfile + rename (Nero pattern)."""
        path.parent.mkdir(parents=True, exist_ok=True)
        fd, tmp_path = tempfile.mkstemp(dir=str(path.parent), suffix=".tmp")
        try:
            with open(fd, "w", encoding="utf-8") as f:
                for entry in entries:
                    f.write(json.dumps(entry, ensure_ascii=False) + "\n")
            Path(tmp_path).replace(path)
        except Exception:
            Path(tmp_path).unlink(missing_ok=True)
            raise

    # ── public API ──

    def add_message(self, role: str, content: str):
        """Append one message to today's JSONL."""
        entry = {
            "timestamp": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
            "role": role,
            "content": content,
        }
        day = self._day_key(entry["timestamp"])
        path = self._path_for_day(day)
        line = json.dumps(entry, ensure_ascii=False) + "\n"
        with _lock:
            path.parent.mkdir(parents=True, exist_ok=True)
            with open(path, "a", encoding="utf-8") as f:
                f.write(line)

    def load_all(self) -> list[dict]:
        """Load every message from all days, sorted by timestamp."""
        all_entries: list[dict] = []
        for path in self._all_day_paths():
            all_entries.extend(self._read_jsonl(path))
        all_entries.sort(key=lambda e: e.get("timestamp", ""))
        return all_entries

    def load_recent(self, n_messages: int = 40) -> list[dict]:
        """Load the most recent N messages for AI context."""
        all_entries = self.load_all()
        return all_entries[-n_messages:] if len(all_entries) > n_messages else all_entries

    def clear_all(self) -> None:
        """Delete all memory files."""
        with _lock:
            for path in self._all_day_paths():
                path.unlink(missing_ok=True)

    def delete_message(self, timestamp: str) -> bool:
        """Remove one message by exact timestamp. Returns True if removed."""
        ts = (timestamp or "").strip()
        if not ts:
            return False
        with _lock:
            day = self._day_key(ts)
            path = self._path_for_day(day)
            if path.exists():
                entries = self._read_jsonl(path)
                kept = [e for e in entries if e.get("timestamp") != ts]
                if len(kept) < len(entries):
                    if kept:
                        self._write_jsonl(path, kept)
                    else:
                        path.unlink(missing_ok=True)
                    return True
            for path in self._all_day_paths():
                entries = self._read_jsonl(path)
                kept = [e for e in entries if e.get("timestamp") != ts]
                if len(kept) < len(entries):
                    if kept:
                        self._write_jsonl(path, kept)
                    else:
                        path.unlink(missing_ok=True)
                    return True
        return False
