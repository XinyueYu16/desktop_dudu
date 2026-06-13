"""
DuDu AsyncScheduler — single asyncio loop with periodic tick.
Manages jobs keyed by id with unix next_at timestamps.
"""

from __future__ import annotations

import asyncio
import time
from collections.abc import Awaitable, Callable
from typing import Any

TICK_INTERVAL = 30.0

JobCallback = Callable[[], Awaitable[None]]


class AsyncScheduler:
    """30-second tick scheduler; fires callbacks when next_at <= now."""

    def __init__(self, tick_interval: float = TICK_INTERVAL):
        self._tick_interval = tick_interval
        self._jobs: dict[str, dict[str, Any]] = {}
        self._task: asyncio.Task | None = None
        self._running = False

    def register(self, job_id: str, next_at: float, callback: JobCallback) -> None:
        self._jobs[job_id] = {"next_at": float(next_at), "callback": callback}

    def cancel(self, job_id: str) -> None:
        self._jobs.pop(job_id, None)

    def reschedule(self, job_id: str, next_at: float) -> None:
        job = self._jobs.get(job_id)
        if job is not None:
            job["next_at"] = float(next_at)

    def has_job(self, job_id: str) -> bool:
        return job_id in self._jobs

    def next_at(self, job_id: str) -> float | None:
        job = self._jobs.get(job_id)
        return job["next_at"] if job else None

    async def start(self) -> None:
        if self._running:
            return
        self._running = True
        self._task = asyncio.create_task(self._loop())

    async def stop(self) -> None:
        self._running = False
        if self._task is not None:
            self._task.cancel()
            try:
                await self._task
            except asyncio.CancelledError:
                pass
            self._task = None

    async def _loop(self) -> None:
        while self._running:
            now = time.time()
            due = [
                job_id
                for job_id, job in self._jobs.items()
                if job["next_at"] <= now
            ]
            for job_id in due:
                job = self._jobs.get(job_id)
                if job is None:
                    continue
                try:
                    await job["callback"]()
                except Exception as exc:
                    print(f"[!] Scheduler job {job_id} failed: {exc}")
            try:
                await asyncio.sleep(self._tick_interval)
            except asyncio.CancelledError:
                break
