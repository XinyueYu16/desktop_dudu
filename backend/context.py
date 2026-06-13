"""
DuDu Context Builder — Assemble messages for LLM API.
Simplified from Nero context.py:
  system → recent memory context → current user message.
"""
from datetime import datetime
from calendar import day_name

from daily_stats import DailyStatsManager
from memory import MemoryManager
from prompts import build_system_prompt
from settings import SettingsManager

# Default: keep the most recent 20 messages (≈10 turns) in context
DEFAULT_CONTEXT_MESSAGES = 20
# Max: 60 messages (≈30 turns) — to avoid token overflow
MAX_CONTEXT_MESSAGES = 60


def _format_context_time_line(ts: str) -> str:
    """[Context time: YYYY-MM-DD HH:MM:SS Weekday] — same format as Nero."""
    t = (ts or "").strip()
    if len(t) < 19:
        return ""
    try:
        dt = datetime.strptime(t[:19], "%Y-%m-%d %H:%M:%S")
    except ValueError:
        return ""
    w = day_name[dt.weekday()]
    return f"[Context time: {dt.strftime('%Y-%m-%d %H:%M:%S')} {w}]"


def _content_for_api(entry: dict) -> str:
    """Format a memory entry for API context.
    User messages get [Context time: ...] prefix (Nero-style timestamp injection).
    Assistant messages are passed through as-is.
    """
    role = entry.get("role", "")
    content = entry.get("content", "") or ""
    if role == "user":
        ts = entry.get("timestamp", "")
        time_line = _format_context_time_line(ts)
        if time_line:
            return f"{time_line}\n\n{content}"
    return content


def inject_yesterday_summary(
    settings: SettingsManager,
    daily_stats: DailyStatsManager | None,
) -> str | None:
    """Return yesterday reminder stats text for system context, if any."""
    if daily_stats is None:
        return None
    summary = daily_stats.build_yesterday_summary()
    if not summary:
        return None
    return summary.get("summary")


def build_messages(
    user_text: str,
    memory: MemoryManager | None,
    settings: SettingsManager,
    mode: str = "default",
    context_messages: int = DEFAULT_CONTEXT_MESSAGES,
    use_memory: bool = True,
    daily_stats: DailyStatsManager | None = None,
) -> list[dict]:
    """
    Assemble the messages list for the chat API.

    Order:
      1. system  — DuDu persona (+ optional mode append from settings)
      2. recent context from memory (user/assistant pairs)
      3. current user_text as user

    mode: "default" | "fortune" | "explore" | "todo_remind" | "pomodoro_complete"

    Returns list of {"role": str, "content": str}.
    """
    ctx_count = min(max(1, context_messages), MAX_CONTEXT_MESSAGES)

    system_content = build_system_prompt(settings, mode)
    yesterday = inject_yesterday_summary(settings, daily_stats)
    if yesterday:
        system_content = f"{system_content}\n\n{yesterday}"

    messages: list[dict] = [
        {"role": "system", "content": system_content}
    ]

    # Recent memory context — with timestamp injection for user messages
    if use_memory and memory is not None:
        recent = memory.load_recent(ctx_count)
        for entry in recent:
            role = entry.get("role", "")
            if role in ("user", "assistant"):
                content = _content_for_api(entry)
                if content:
                    messages.append({"role": role, "content": content})

    # Current user message — with timestamp
    now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    w = day_name[datetime.now().weekday()]
    time_line = f"[Context time: {now} {w}]"
    user_stripped = user_text.strip()
    user_content = f"{time_line}\n\n{user_stripped}"

    # Avoid duplicate if already in memory
    if messages and messages[-1]["role"] == "user" and messages[-1]["content"].strip().endswith(user_stripped):
        pass
    else:
        messages.append({"role": "user", "content": user_content})

    return messages
