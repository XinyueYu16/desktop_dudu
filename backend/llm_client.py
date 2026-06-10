"""
DuDu LLM Client — Async streaming for DeepSeek (OpenAI-compatible) API.
Uses httpx directly — no openai package needed.
"""
import json
import logging
from collections.abc import AsyncGenerator

import httpx

log = logging.getLogger("dudu.llm")

# DeepSeek defaults — override via constructor or env
DEFAULT_BASE_URL = "https://api.deepseek.com"
DEFAULT_MODEL = "deepseek-v4-flash"
DEFAULT_MAX_TOKENS = 1024
DEFAULT_TEMPERATURE = 0.9


class LLMClient:
    """Async DeepSeek client with streaming support."""

    def __init__(
        self,
        api_key: str,
        base_url: str = DEFAULT_BASE_URL,
        model: str = DEFAULT_MODEL,
        max_tokens: int = DEFAULT_MAX_TOKENS,
        temperature: float = DEFAULT_TEMPERATURE,
    ):
        self._api_key = api_key
        self._base_url = base_url.rstrip("/")
        self._model = model
        self._max_tokens = max_tokens
        self._temperature = temperature
        self._endpoint = f"{self._base_url}/chat/completions"

    # ── streaming ──

    async def stream_chat(
        self,
        messages: list[dict],
        thinking: bool = False,
        model: str | None = None,
    ) -> AsyncGenerator[str, None]:
        """
        Stream chat completion chunks.
        Yields content delta strings as they arrive.
        """
        headers = {
            "Authorization": f"Bearer {self._api_key}",
            "Content-Type": "application/json",
            "Accept": "text/event-stream",
        }
        payload = {
            "model": model or self._model,
            "messages": messages,
            "max_tokens": self._max_tokens,
            "temperature": self._temperature,
            "stream": True,
        }
        if thinking:
            payload["thinking"] = {"type": "enabled"}

        async with httpx.AsyncClient(timeout=120.0) as client:
            async with client.stream(
                "POST", self._endpoint, json=payload, headers=headers
            ) as response:
                if response.status_code != 200:
                    body = await response.aread()
                    log.error("DeepSeek API error %d: %s", response.status_code, body)
                    raise RuntimeError(
                        f"DeepSeek API error ({response.status_code}): "
                        f"{body[:300]}"
                    )

                async for line in response.aiter_lines():
                    line = line.strip()
                    if not line:
                        continue
                    if line.startswith("data:"):
                        data_str = line[5:].strip()
                        if data_str == "[DONE]":
                            return
                        try:
                            chunk = json.loads(data_str)
                            choices = chunk.get("choices", [])
                            if choices:
                                delta = choices[0].get("delta", {})
                                content = delta.get("content") or ""
                                if content:
                                    yield content
                        except json.JSONDecodeError:
                            continue

    # ── non-streaming (fallback / fortune / explore) ──

    async def chat(self, messages: list[dict]) -> str:
        """Non-streaming chat — returns full reply."""
        headers = {
            "Authorization": f"Bearer {self._api_key}",
            "Content-Type": "application/json",
        }
        payload = {
            "model": self._model,
            "messages": messages,
            "max_tokens": self._max_tokens,
            "temperature": self._temperature,
            "stream": False,
        }

        async with httpx.AsyncClient(timeout=120.0) as client:
            resp = await client.post(
                self._endpoint, json=payload, headers=headers
            )
            if resp.status_code != 200:
                body = resp.text
                log.error("DeepSeek API error %d: %s", resp.status_code, body)
                raise RuntimeError(
                    f"DeepSeek API error ({resp.status_code}): {body[:300]}"
                )
            data = resp.json()
            choices = data.get("choices", [])
            if choices:
                return choices[0].get("message", {}).get("content", "")
            return ""

    def get_model_name(self) -> str:
        return self._model
