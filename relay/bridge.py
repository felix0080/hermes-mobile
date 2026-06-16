#!/usr/bin/env python3
"""Hermes Relay Bridge — connects local Hermes to a Relay server.

Usage:
    python3 bridge.py <relay_url> [--name "My Mac"]
    python3 bridge.py ws://vps:9920 --name "Home Server"

Requires Hermes Webhook to be running:
    hermes webhook subscribe hermes-bridge

This script:
    1. Connects to Relay via WebSocket
    2. Registers with a friendly name
    3. Listens for chat messages from Relay
    4. Forwards to local Hermes Webhook
    5. Streams response chunks back to Relay
"""

import argparse
import asyncio
import json
import logging
import sys
import socket
from typing import Optional

try:
    import aiohttp
    import websockets
except ImportError:
    print("Missing packages. Install: pip install aiohttp websockets")
    raise

logging.basicConfig(level=logging.INFO, format="%(asctime)s [bridge] %(message)s")
logger = logging.getLogger("bridge")

HERMES_WEBHOOK = "http://127.0.0.1:8765/webhooks/hermes-bridge"


class Bridge:
    def __init__(self, relay_url: str, name: str, auth: str = ""):
        self._relay = relay_url
        self._name = name
        self._auth = auth
        self._ws: Optional[websockets.WebSocketClientProtocol] = None

    async def run(self):
        logger.info(f"Connecting to Relay: {self._relay}")
        async with aiohttp.ClientSession() as session:
            self._session = session
            while True:
                try:
                    async with websockets.connect(self._relay) as ws:
                        self._ws = ws
                        await self._register()
                        logger.info("Connected. Waiting for messages...")
                        await self._message_loop()
                except (websockets.ConnectionClosed, OSError) as e:
                    logger.warning(f"Disconnected: {e}. Reconnecting in 5s...")
                    await asyncio.sleep(5)

    async def _register(self):
        msg = {"type": "register", "name": self._name}
        if self._auth:
            msg["auth"] = self._auth
        await self._ws.send(json.dumps(msg))

    async def _message_loop(self):
        async for raw in self._ws:
            try:
                msg = json.loads(raw)
            except json.JSONDecodeError:
                continue

            if msg.get("type") == "chat":
                app_id = msg.get("from", "")
                content = msg.get("content", "")
                logger.info(f"Chat from {app_id}: {content[:50]}...")
                asyncio.create_task(self._forward(app_id, content))

    async def _forward(self, app_id: str, content: str):
        """Forward chat to Hermes Webhook and stream response back."""
        try:
            async with self._session.post(
                HERMES_WEBHOOK,
                json={"message": content},
                timeout=aiohttp.ClientTimeout(total=120),
            ) as resp:
                # Read response as text
                text = await resp.text()
                if text:
                    # Stream response in ~50 char chunks for smooth UX
                    for i in range(0, len(text), 50):
                        chunk = text[i : i + 50]
                        await self._ws.send(json.dumps({
                            "type": "chunk",
                            "to": app_id,
                            "delta": chunk,
                        }))
                        await asyncio.sleep(0.05)  # Small delay between chunks
                await self._ws.send(json.dumps({"type": "done", "to": app_id}))
        except Exception as e:
            logger.error(f"Forward failed: {e}")


def get_default_name() -> str:
    try:
        return socket.gethostname()
    except Exception:
        return "Hermes"


async def main():
    parser = argparse.ArgumentParser(description="Hermes Relay Bridge")
    parser.add_argument("relay_url", help="WebSocket URL of Relay server")
    parser.add_argument("--name", type=str, default=get_default_name())
    parser.add_argument("--auth", type=str, default="")
    args = parser.parse_args()

    bridge = Bridge(args.relay_url, args.name, args.auth)
    await bridge.run()


if __name__ == "__main__":
    asyncio.run(main())
