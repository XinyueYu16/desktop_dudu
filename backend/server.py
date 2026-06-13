"""
DuDu Backend — WebSocket Server
Handles: AI chat (DeepSeek), pet actions, system tray.
"""
import asyncio
import json
import os
import re
import threading
import time
import uuid
from pathlib import Path

from PIL import Image, ImageDraw
import pystray
from websockets.asyncio.server import serve

from context import build_messages
from daily_stats import DailyStatsManager
from inventory import InventoryManager
from llm_client import LLMClient
from memory import MemoryManager
from pomodoro import PomodoroTimer
from reminders import ReminderScheduler
from scheduler import AsyncScheduler
from settings import SettingsManager
from stargazing import StargazingService
from todos import TodoScheduler, TodoStore

# ── .env loader (no extra dependencies) ──

def _load_dotenv():
    """Load KEY=VALUE pairs from .env beside server.py into os.environ."""
    path = Path(__file__).with_name(".env")
    try:
        with open(path, "r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith("#"):
                    continue
                if "=" in line:
                    k, v = line.split("=", 1)
                    k, v = k.strip(), v.strip()
                    if k and k not in os.environ:
                        os.environ[k] = v
    except FileNotFoundError:
        pass

_load_dotenv()

# ── Config ──

API_KEY = os.getenv("DEEPSEEK_API_KEY", "")
API_BASE = os.getenv("DEEPSEEK_API_BASE", "https://api.deepseek.com")
MODEL = os.getenv("DEEPSEEK_MODEL", "deepseek-v4-flash")

# 旧模型名 → V4 规范名（见 https://api-docs.deepseek.com/zh-cn/ ）
_LEGACY_MODEL_MAP = {
    "deepseek-chat": "deepseek-v4-flash",
    "deepseek-reasoner": "deepseek-v4-pro",
}

# Shared state
_godot_ws = None
_tray_icon = None
_window_visible = True
_loop = None
_llm: LLMClient | None = None
_memory = MemoryManager()
_settings = SettingsManager()
_scheduler = AsyncScheduler()
_daily_stats = DailyStatsManager()
_reminders: ReminderScheduler | None = None
_todo_store = TodoStore()
_todos: TodoScheduler | None = None
_inventory = InventoryManager()
_pomodoro: PomodoroTimer | None = None
_stargazing: StargazingService | None = None


# ── Tray Icon ──

def _make_tray_image():
    # Load placeholder cat image for tray icon
    placeholder = Path(__file__).parent.parent / "assets" / "占位.png"
    try:
        img = Image.open(placeholder).convert("RGBA")
        img = img.resize((64, 64), Image.LANCZOS)
        return img
    except Exception:
        # Fallback blue circle
        img = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
        draw = ImageDraw.Draw(img)
        draw.ellipse([2, 2, 62, 62], fill=(90, 133, 181, 255))
        draw.ellipse([20, 22, 28, 28], fill=(20, 24, 35, 255))
        draw.ellipse([36, 22, 44, 28], fill=(20, 24, 35, 255))
        draw.arc([22, 30, 42, 42], 200, 340, fill=(20, 24, 35, 255), width=2)
        return img


def _on_tray_default(icon, item):
    asyncio.run_coroutine_threadsafe(_toggle_window(), _loop)


def _on_tray_exit(icon, item):
    icon.stop()
    asyncio.run_coroutine_threadsafe(_broadcast("app.quit", {}), _loop)


async def _toggle_window():
    global _window_visible
    if _window_visible:
        await _broadcast("window.hide", {})
    else:
        await _broadcast("window.restore", {})
    _window_visible = not _window_visible


def _start_tray():
    global _tray_icon
    menu = pystray.Menu(
        pystray.MenuItem("显示/隐藏嘟嘟", _on_tray_default, default=True),
        pystray.Menu.SEPARATOR,
        pystray.MenuItem("退出", _on_tray_exit),
    )
    _tray_icon = pystray.Icon("dudu", _make_tray_image(), "嘟嘟", menu)
    _tray_icon.run_detached()


# ── WebSocket ──

async def handler(websocket):
    global _godot_ws, _window_visible
    _godot_ws = websocket
    print(f"[+] Godot connected ({websocket.remote_address})")

    # Push persisted state on connect so client never guesses defaults
    await _send("settings.data", _settings.get_all())
    await _send_reminders_data()
    await _send_todos_data()
    await _send_inventory_data()
    await _send_pomodoro_state()
    await _send_yesterday_stats()
    await _send_history()

    try:
        async for raw in websocket:
            msg = json.loads(raw)
            msg_type = msg.get("type", "")

            match msg_type:
                case "user.chat":
                    text = (msg.get("text") or "").strip()
                    mode = (msg.get("mode") or "default").strip() or "default"
                    if text:
                        await _handle_chat(
                            text,
                            mode,
                            thinking=msg.get("thinking"),
                            use_memory=msg.get("use_memory"),
                            record_memory=msg.get("record_memory"),
                        )
                    else:
                        await _send("assistant.done", {
                            "full_text": "你想说什么呀，喵？"
                        })

                case "pet.poke":
                    await _send("pet.action", {
                        "animation": "happy",
                        "bubble_text": "干嘛戳我！"
                    })

                case "window.hidden":
                    _window_visible = False

                case "window.shown":
                    _window_visible = True

                case "app.quit":
                    if _tray_icon:
                        _tray_icon.stop()
                    break

                case "history.request":
                    await _send_history()

                case "history.clear":
                    _memory.clear_all()
                    await _send("history.cleared", {})

                case "history.delete":
                    ts = (msg.get("timestamp") or "").strip()
                    ok = _memory.delete_message(ts)
                    await _send("history.deleted", {"timestamp": ts, "ok": ok})

                case "ping":
                    await _send("pong", {})

                case "settings.get":
                    await _send("settings.data", _settings.get_all())

                case "settings.set":
                    key = (msg.get("key") or "").strip()
                    if key and "value" in msg:
                        _settings.set(key, msg["value"])
                        if key.startswith("chat."):
                            _llm = _make_llm()
                        await _send("settings.updated", _settings.get_all())

                case "settings.set_bulk":
                    updates = msg.get("updates") or {}
                    if isinstance(updates, dict) and updates:
                        _settings.set_bulk(updates)
                        if any(str(k).startswith("chat.") for k in updates):
                            _llm = _make_llm()
                        await _send("settings.updated", _settings.get_all())

                case "reminders.get":
                    await _send_reminders_data()

                case "reminders.set":
                    items = msg.get("items")
                    if _reminders is not None and isinstance(items, list):
                        saved = _reminders.set_items(items)
                        await _send("reminders.data", {"items": saved})

                case "reminders.ack":
                    rid = (msg.get("id") or "").strip()
                    if _reminders is not None and rid:
                        await _reminders.handle_ack(rid)
                        await _send("reminders.acked", {"id": rid, "ok": True})

                case "todos.get":
                    await _send_todos_data()

                case "todos.set":
                    items = msg.get("items")
                    if isinstance(items, list):
                        saved = _todo_store.replace_all(items)
                        if _todos is not None:
                            _todos.on_todos_changed()
                        await _send("todos.data", {"items": saved})

                case "todos.add":
                    text = (msg.get("text") or "").strip()
                    remind_at = msg.get("remind_at")
                    if text:
                        try:
                            ra = float(remind_at) if remind_at is not None else None
                        except (TypeError, ValueError):
                            ra = None
                        item = _todo_store.add(text, ra)
                        if _todos is not None:
                            _todos.on_todos_changed()
                        await _send("todos.data", {"items": _todo_store.get_all()})
                        await _send("todos.added", {"item": item})

                case "todos.update":
                    tid = (msg.get("id") or "").strip()
                    if tid:
                        fields = {}
                        if "text" in msg:
                            fields["text"] = msg["text"]
                        if "done" in msg:
                            fields["done"] = bool(msg["done"])
                        if "remind_at" in msg:
                            raw_ra = msg["remind_at"]
                            if raw_ra is None:
                                fields["remind_at"] = None
                            else:
                                try:
                                    fields["remind_at"] = float(raw_ra)
                                except (TypeError, ValueError):
                                    pass
                        updated = _todo_store.update(tid, **fields)
                        if updated is not None:
                            if _todos is not None:
                                _todos.on_todos_changed()
                            await _send("todos.data", {"items": _todo_store.get_all()})

                case "todos.delete":
                    tid = (msg.get("id") or "").strip()
                    if tid and _todo_store.delete(tid):
                        if _todos is not None:
                            _todos.on_todos_changed()
                        await _send("todos.data", {"items": _todo_store.get_all()})

                case "pomodoro.start":
                    if _pomodoro is not None:
                        task = str(msg.get("task") or msg.get("focus") or "")
                        try:
                            duration = int(msg.get("duration_minutes") or msg.get("duration") or 25)
                        except (TypeError, ValueError):
                            duration = 25
                        state = await _pomodoro.start(task, duration)
                        await _send("pomodoro.state", state)

                case "pomodoro.pause":
                    if _pomodoro is not None:
                        state = await _pomodoro.pause()
                        await _send("pomodoro.state", state)

                case "pomodoro.resume":
                    if _pomodoro is not None:
                        state = await _pomodoro.resume()
                        await _send("pomodoro.state", state)

                case "pomodoro.abort":
                    if _pomodoro is not None:
                        state = await _pomodoro.abort()
                        await _send("pomodoro.state", state)

                case "pomodoro.get":
                    await _send_pomodoro_state()

                case "inventory.get":
                    await _send_inventory_data()

                case "stargazing.get":
                    if _stargazing is not None:
                        loop = asyncio.get_running_loop()
                        chart = await loop.run_in_executor(None, _stargazing.build_chart)
                        await _send("stargazing.chart", chart)

                case _:
                    print(f"[?] Unknown msg type: {msg_type}")

    except Exception as e:
        print(f"[!] Error: {e}")
    finally:
        print(f"[-] Godot disconnected")
        _godot_ws = None
        # Auto-stop tray when Godot exits
        if _tray_icon:
            _tray_icon.stop()
            _tray_icon = None


# ── Chat handler ──

async def _handle_chat(
    user_text: str,
    mode: str = "default",
    *,
    thinking=None,
    use_memory=None,
    record_memory=None,
):
    """Process user chat: optional save → build context → stream LLM → optional save reply."""
    thinking_on = (
        bool(thinking)
        if thinking is not None
        else bool(_settings.get("chat.thinking_enabled"))
    )
    # Short-reply modes — skip slow reasoning pass
    if mode in ("fortune", "explore", "todo_remind", "pomodoro_complete"):
        thinking_on = False
    use_mem = (
        bool(use_memory)
        if use_memory is not None
        else bool(_settings.get("chat.use_memory"))
    )
    record_mem = (
        bool(record_memory)
        if record_memory is not None
        else bool(_settings.get("chat.record_memory"))
    )

    if record_mem:
        _memory.add_message("user", user_text)

    mem = _memory if use_mem else None
    messages = build_messages(
        user_text, mem, _settings, mode=mode, use_memory=use_mem,
        daily_stats=_daily_stats,
    )

    if _llm is None:
        await _send("assistant.chunk", {"delta": "API 还没配置好喵... 让主人去设置一下 DeepSeek Key"})
        await _send("assistant.done", {"full_text": "API 还没配置好喵... 让主人去设置一下 DeepSeek Key"})
        return

    # Stream
    full_text = ""
    api_model = _resolve_model(thinking_on)
    try:
        async for delta in _llm.stream_chat(
            messages, thinking=thinking_on, model=api_model
        ):
            full_text += delta
            await _send("assistant.chunk", {"delta": delta})
    except Exception as e:
        err_text = f"唔...脑袋卡住了喵...（{e}）"
        if not full_text:
            full_text = err_text
            await _send("assistant.chunk", {"delta": err_text})
        print(f"[!] LLM error: {e}")

    if not full_text.strip():
        full_text = "唔...嘟嘟一时说不出话，再试一次喵~"
        await _send("assistant.chunk", {"delta": full_text})

    # Done
    await _send("assistant.done", {"full_text": full_text})

    # Parse animation commands from LLM output
    for m in re.finditer(r"\[animation:\s*(\w+)\]", full_text):
        anim = m.group(1).strip().lower()
        if anim in ("idle", "talking", "happy", "bite", "faint", "petted"):
            await _send("pet.action", {"animation": anim, "bubble_text": ""})

    # Save assistant reply
    if record_mem and full_text.strip():
        _memory.add_message("assistant", full_text.strip())


# ── History ──

async def _send_history():
    """Send all chat history to the frontend on connect."""
    all_msgs = _memory.load_all()
    if not all_msgs:
        return
    await _send("history.data", {"messages": all_msgs})


async def _send_reminders_data():
    if _reminders is None:
        return
    await _send("reminders.data", {"items": _reminders.get_items()})


async def _send_todos_data():
    await _send("todos.data", {"items": _todo_store.get_all()})


async def _send_inventory_data():
    await _send("inventory.data", {"items": _inventory.get_items_enriched()})


async def _send_pomodoro_state():
    if _pomodoro is None:
        return
    await _send("pomodoro.state", _pomodoro.get_state())


async def _send_yesterday_stats():
    summary = _daily_stats.build_yesterday_summary()
    if summary:
        await _send("daily_stats.yesterday", summary)


# ── Send helpers ──

async def _send(msg_type: str, payload: dict):
    if _godot_ws:
        msg = {
            "type": msg_type,
            "id": uuid.uuid4().hex[:8],
            "timestamp": time.time(),
            "payload": payload,
        }
        await _godot_ws.send(json.dumps(msg, ensure_ascii=False))


async def _broadcast(msg_type: str, payload: dict):
    await _send(msg_type, payload)


def _resolve_api_key() -> str:
    key = (_settings.get("chat.api_key") or "").strip()
    if key:
        return key
    return API_KEY


def _resolve_api_base() -> str:
    base = (_settings.get("chat.api_base") or "").strip()
    if base:
        return base.rstrip("/")
    return API_BASE.rstrip("/")


def _resolve_model(thinking: bool = False) -> str:
    model = (_settings.get("chat.model") or MODEL or "").strip()
    api_model = _LEGACY_MODEL_MAP.get(model, model)
    # 思考模式：Flash 切到 Pro（官方思考示例用 v4-pro）
    if thinking and api_model == "deepseek-v4-flash":
        api_model = "deepseek-v4-pro"
    return api_model


def _make_llm() -> LLMClient | None:
    api_key = _resolve_api_key()
    if not api_key:
        return None
    return LLMClient(
        api_key=api_key,
        base_url=_resolve_api_base(),
        model=_resolve_model(),
        temperature=_settings.get("chat.temperature") or 0.8,
    )


# ── Main ──

async def main():
    global _loop, _llm, _reminders, _todos, _pomodoro, _stargazing
    _loop = asyncio.get_running_loop()
    _reminders = ReminderScheduler(_scheduler, _settings, _daily_stats, _send)
    _reminders.sync_from_settings()
    _todos = TodoScheduler(_scheduler, _todo_store, _send, _handle_chat)
    if _todo_store.repair_remind_times():
        print("[TODO] Repaired remind_at from remind_at_text (Asia/Shanghai)")
    _todos.sync_all()
    _pomodoro = PomodoroTimer(_inventory, _send, _handle_chat)
    _stargazing = StargazingService(_settings)
    await _scheduler.start()
    threading.Thread(target=_start_tray, daemon=True).start()

    # Init LLM client
    if API_KEY or _resolve_api_key():
        _llm = _make_llm()
        print(f"[LLM] DeepSeek ready: {_resolve_model()} @ {_resolve_api_base()}")
    else:
        print("[LLM] No DEEPSEEK_API_KEY set — chat will show placeholder")

    print("=" * 50)
    print("  DuDu Backend — ws://127.0.0.1:9876")
    print("  System tray: always visible, click to toggle")
    print("=" * 50)

    async with serve(handler, "127.0.0.1", 9876):
        await asyncio.Future()


if __name__ == "__main__":
    asyncio.run(main())
