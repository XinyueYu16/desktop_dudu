"""
DuDu PomodoroTimer — focus session with explore loot on complete.
"""

from __future__ import annotations

import asyncio
import time
from collections.abc import Awaitable, Callable
from typing import Any

from inventory import InventoryManager

SendFn = Callable[[str, dict], Awaitable[None]]
ChatFn = Callable[..., Awaitable[None]]


class PomodoroTimer:
    """Async focus timer: idle → focusing → complete."""

    def __init__(
        self,
        inventory: InventoryManager,
        send_fn: SendFn,
        chat_fn: ChatFn,
    ):
        self._inventory = inventory
        self._send = send_fn
        self._chat = chat_fn
        self._task: asyncio.Task | None = None
        self._state: str = "idle"
        self._task_name: str = ""
        self._duration_sec: int = 0
        self._remaining_sec: int = 0
        self._started_at: float = 0.0
        self._paused: bool = False
        self._pause_started: float = 0.0
        self._paused_total: float = 0.0

    def get_state(self) -> dict[str, Any]:
        return {
            "state": self._state,
            "task": self._task_name,
            "duration_sec": self._duration_sec,
            "remaining_sec": self._remaining_sec,
            "paused": self._paused,
        }

    async def start(self, task: str, duration_minutes: int) -> dict:
        await self.abort(silent=True)
        mins = max(1, min(int(duration_minutes or 25), 180))
        self._state = "focusing"
        self._task_name = str(task or "专注").strip() or "专注"
        self._duration_sec = mins * 60
        self._remaining_sec = self._duration_sec
        self._started_at = time.time()
        self._paused = False
        self._paused_total = 0.0

        await self._send(
            "pomodoro.phase_change",
            {
                "phase": "focusing",
                "bubble_text": "嘟嘟去角落蹲着了…专注吧喵~",
                "task": self._task_name,
            },
        )
        await self._send("pet.action", {"animation": "faint", "bubble_text": ""})
        self._task = asyncio.create_task(self._tick_loop())
        await self._send_tick()
        return self.get_state()

    async def pause(self) -> dict:
        if self._state != "focusing" or self._paused:
            return self.get_state()
        self._paused = True
        self._pause_started = time.time()
        await self._send(
            "pomodoro.phase_change",
            {"phase": "paused", "bubble_text": "暂停一下喵~"},
        )
        return self.get_state()

    async def resume(self) -> dict:
        if self._state != "focusing" or not self._paused:
            return self.get_state()
        self._paused_total += time.time() - self._pause_started
        self._paused = False
        await self._send(
            "pomodoro.phase_change",
            {"phase": "focusing", "bubble_text": "继续专注喵~"},
        )
        return self.get_state()

    async def abort(self, *, silent: bool = False) -> dict:
        if self._task is not None:
            self._task.cancel()
            try:
                await self._task
            except asyncio.CancelledError:
                pass
            self._task = None
        was_active = self._state == "focusing"
        self._state = "idle"
        self._remaining_sec = 0
        self._paused = False
        if was_active and not silent:
            await self._send(
                "pomodoro.phase_change",
                {"phase": "aborted", "bubble_text": "好吧…下次再继续喵"},
            )
            await self._send("pet.action", {"animation": "idle", "bubble_text": ""})
        return self.get_state()

    async def _tick_loop(self) -> None:
        try:
            while self._state == "focusing" and self._remaining_sec > 0:
                await asyncio.sleep(1.0)
                if self._paused:
                    continue
                elapsed = int(time.time() - self._started_at - self._paused_total)
                self._remaining_sec = max(0, self._duration_sec - elapsed)
                await self._send_tick()
                if self._remaining_sec <= 0:
                    await self._complete()
                    return
        except asyncio.CancelledError:
            raise

    async def _send_tick(self) -> None:
        await self._send(
            "pomodoro.tick",
            {
                "phase": "paused" if self._paused else "focusing",
                "remaining": self._remaining_sec,
                "total": self._duration_sec,
                "task": self._task_name,
            },
        )

    async def _complete(self) -> None:
        self._state = "idle"
        self._task = None
        loot = self._inventory.roll_and_add()
        await self._send(
            "pomodoro.phase_change",
            {
                "phase": "complete",
                "bubble_text": "嘟嘟回来啦！看看带了什么~",
                "task": self._task_name,
            },
        )
        await self._send("pet.action", {"animation": "happy", "bubble_text": ""})
        payload: dict[str, Any] = {
            "task": self._task_name,
            "duration_sec": self._duration_sec,
            "item": loot,
        }
        await self._send("pomodoro.complete", payload)
        await self._send(
            "inventory.updated",
            {"items": self._inventory.get_items_enriched()},
        )
        if loot:
            prompt = (
                f"[番茄钟完成] 姐姐完成了「{self._task_name}」"
                f"（{self._duration_sec // 60}分钟）。"
                f"嘟嘟探索带回了：{loot.get('emoji', '')}{loot.get('name', '小物件')}。"
                f"用猫的语气简短夸奖并描述这件小物件。"
            )
        else:
            prompt = (
                f"[番茄钟完成] 姐姐完成了「{self._task_name}」"
                f"（{self._duration_sec // 60}分钟）。用猫的语气简短夸奖。"
            )
        await self._chat(
            prompt,
            "pomodoro_complete",
            thinking=False,
            use_memory=True,
            record_memory=True,
        )
