"""
DuDu Backend — WebSocket Server
Handles: AI chat (DeepSeek), pet actions, system tray.
"""
import asyncio
import json
import os
import threading
import time
import uuid
from pathlib import Path

from PIL import Image, ImageDraw
import pystray
from websockets.asyncio.server import serve

from context import build_messages
from llm_client import LLMClient
from memory import MemoryManager
from settings import SettingsManager

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
API_BASE = os.getenv("DEEPSEEK_API_BASE", "https://api.deepseek.com/v1")
MODEL = os.getenv("DEEPSEEK_MODEL", "deepseek-chat")

# Shared state
_godot_ws = None
_tray_icon = None
_window_visible = True
_loop = None
_llm: LLMClient | None = None
_memory = MemoryManager()
_settings = SettingsManager()


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

    # Send full history on connect
    await _send_history()

    try:
        async for raw in websocket:
            msg = json.loads(raw)
            msg_type = msg.get("type", "")

            match msg_type:
                case "user.chat":
                    text = (msg.get("text") or "").strip()
                    if text:
                        await _handle_chat(text)
                    else:
                        await _send("assistant.done", {
                            "full_text": "你想说什么呀，喵？"
                        })

                case "pet.poke":
                    await _send("pet.action", {
                        "animation": "petted",
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

async def _handle_chat(user_text: str):
    """Process user chat: save → build context → stream LLM → save reply."""
    # Save user message
    _memory.add_message("user", user_text)

    # Build messages
    messages = build_messages(user_text, _memory)

    if _llm is None:
        await _send("assistant.chunk", {"delta": "API 还没配置好喵... 让主人去设置一下 DeepSeek Key"})
        await _send("assistant.done", {"full_text": "API 还没配置好喵... 让主人去设置一下 DeepSeek Key"})
        return

    # Stream
    full_text = ""
    try:
        async for delta in _llm.stream_chat(messages):
            full_text += delta
            await _send("assistant.chunk", {"delta": delta})
    except Exception as e:
        err_text = f"唔...脑袋卡住了喵...（{e}）"
        if not full_text:
            full_text = err_text
            await _send("assistant.chunk", {"delta": err_text})
        print(f"[!] LLM error: {e}")

    # Done
    await _send("assistant.done", {"full_text": full_text})

    # Save assistant reply
    if full_text.strip():
        _memory.add_message("assistant", full_text.strip())


# ── History ──

async def _send_history():
    """Send all chat history to the frontend on connect."""
    all_msgs = _memory.load_all()
    if not all_msgs:
        return
    await _send("history.data", {"messages": all_msgs})


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


def _make_llm() -> LLMClient | None:
    if not API_KEY:
        return None
    return LLMClient(
        api_key=API_KEY,
        base_url=API_BASE,
        model=_settings.get("chat.model") or MODEL,
        temperature=_settings.get("chat.temperature") or 0.8,
    )


# ── Main ──

async def main():
    global _loop, _llm
    _loop = asyncio.get_running_loop()
    threading.Thread(target=_start_tray, daemon=True).start()

    # Init LLM client
    if API_KEY:
        _llm = _make_llm()
        print(f"[LLM] DeepSeek ready: {_settings.get('chat.model')} @ {API_BASE}")
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
