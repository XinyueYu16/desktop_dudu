"""Quick test for TodoStore and scheduler integration."""
import asyncio
import time

from scheduler import AsyncScheduler
from todos import TodoScheduler, TodoStore


async def test_todo_remind_scheduled():
    sent: list[tuple[str, dict]] = []
    chats: list[tuple[str, str]] = []

    async def send_fn(msg_type: str, payload: dict):
        sent.append((msg_type, payload))

    async def chat_fn(text: str, mode: str, **kwargs):
        chats.append((text, mode))

    store = TodoStore()
    store.replace_all([])
    item = store.add("测试待办", time.time() + 1.0)

    scheduler = AsyncScheduler(tick_interval=0.5)
    todos = TodoScheduler(scheduler, store, send_fn, chat_fn)
    todos.sync_all()

    await scheduler.start()
    await asyncio.sleep(2.5)
    await scheduler.stop()

    reminds = [p for t, p in sent if t == "todo.remind"]
    assert reminds, f"expected todo.remind, got {sent}"
    assert chats and chats[0][1] == "todo_remind"
    updated = store.get_all()
    assert updated[0].get("remind_at") is None
    print("OK todo remind", reminds[0])


if __name__ == "__main__":
    asyncio.run(test_todo_remind_scheduled())
