#!/usr/bin/env python3
"""Hermes Relay Bridge v2 — websockets 16.0 + Hermes API Server."""

import argparse
import asyncio
import json
import logging
import socket

import aiohttp
from websockets.asyncio.client import connect as ws_connect

logging.basicConfig(level=logging.INFO, format="%(asctime)s [bridge] %(message)s")
logger = logging.getLogger("bridge")

HERMES_API = "http://127.0.0.1:8642/v1/chat/completions"
HERMES_KEY = "hermes-mobile-dev"


class Bridge:
    def __init__(self, relay_url: str, name: str, auth: str = ""):
        self._relay = relay_url
        self._name = name
        self._auth = auth
        self._ws = None

    async def run(self):
        logger.info(f"→ Relay: {self._relay}")
        async with aiohttp.ClientSession() as session:
            while True:
                try:
                    async with ws_connect(self._relay) as ws:
                        self._ws = ws
                        await self._register()
                        logger.info("✓ Connected")
                        await self._loop(session)
                except Exception as e:
                    logger.warning(f"Disconnected: {e}. Retry 5s...")
                    await asyncio.sleep(5)

    async def _register(self):
        msg = {"type": "register", "name": self._name}
        if self._auth:
            msg["auth"] = self._auth
        await self._ws.send(json.dumps(msg))

    async def _loop(self, session):
        async for raw in self._ws:
            try:
                msg = json.loads(raw)
            except json.JSONDecodeError:
                continue
            if msg.get("type") == "chat":
                asyncio.create_task(self._forward(session, msg.get("from", ""), msg.get("content", "")))

    async def _forward(self, session, app_id: str, content: str):
        try:
            headers = {"Content-Type": "application/json", "Accept": "text/event-stream"}
            if HERMES_KEY:
                headers["Authorization"] = f"Bearer {HERMES_KEY}"

            async with session.post(HERMES_API, json={
                "model": "hermes-agent",
                "messages": [{"role": "user", "content": content}],
                "stream": True,
            }, headers=headers, timeout=aiohttp.ClientTimeout(total=120)) as resp:
                async for line in resp.content:
                    text = line.decode("utf-8").strip()
                    if text.startswith("data: ") and "[DONE]" not in text:
                        try:
                            data = json.loads(text[6:])
                            choices = data.get("choices", [])
                            if choices:
                                delta = choices[0].get("delta", {}).get("content", "")
                                if delta:
                                    await self._ws.send(json.dumps({"type": "chunk", "to": app_id, "delta": delta}))
                        except Exception:
                            pass
                await self._ws.send(json.dumps({"type": "done", "to": app_id}))
        except Exception as e:
            logger.error(f"Forward error: {e}")


async def main():
    p = argparse.ArgumentParser()
    p.add_argument("relay_url")
    p.add_argument("--name", type=str, default=socket.gethostname())
    p.add_argument("--auth", type=str, default="")
    args = p.parse_args()
    await Bridge(args.relay_url, args.name, args.auth).run()


if __name__ == "__main__":
    asyncio.run(main())
