"""
Hermes Relay Platform Adapter.

Connects Hermes to a Hermes Relay server via WebSocket.
Place this file in: ~/.hermes/hermes-agent/gateway/platforms/

Configuration (environment variables):
    HERMES_RELAY_URL=ws://your-vps:9920     # Relay server URL
    HERMES_RELAY_NAME=My Mac                # Display name (optional, default: hostname)
    HERMES_RELAY_AUTH=secret                # Relay auth key (optional)

Enable in config.yaml:
    gateway:
      platforms:
        hermes_relay:
          enabled: true

Or set env vars and the gateway auto-detects it.
"""

import asyncio
import json
import logging
import os
import socket
import uuid
from typing import Any, Dict, Optional, Set

from gateway.config import Platform, PlatformConfig
from gateway.platforms.base import (
    BasePlatformAdapter,
    SendResult,
)

logger = logging.getLogger(__name__)

# Optional dependency: pip install websockets
try:
    import websockets
    from websockets.client import WebSocketClientProtocol

    WEBSOCKETS_AVAILABLE = True
except ImportError:
    WEBSOCKETS_AVAILABLE = False
    WebSocketClientProtocol = None  # type: ignore


RELAY_URL = os.getenv("HERMES_RELAY_URL", "")
RELAY_AUTH = os.getenv("HERMES_RELAY_AUTH", "")


def get_default_name() -> str:
    return os.getenv("HERMES_RELAY_NAME") or socket.gethostname()


def check_hermes_relay_requirements() -> bool:
    """Check if Relay dependencies are available and URL is configured."""
    return WEBSOCKETS_AVAILABLE and bool(RELAY_URL)


class HermesRelayAdapter(BasePlatformAdapter):
    """WebSocket client that connects Hermes to a Relay server."""

    def __init__(self, config: PlatformConfig):
        super().__init__(config, Platform("hermes_relay"))  # type: ignore[arg-type]
        extra = config.extra or {}
        self._relay_url: str = extra.get("url", RELAY_URL)
        self._name: str = extra.get("name", get_default_name())
        self._auth: str = extra.get("auth", RELAY_AUTH)
        self._bridge_id: str = str(uuid.uuid4())[:8]
        self._ws: Optional["WebSocketClientProtocol"] = None
        self._running = False

    async def connect(self) -> bool:
        """Connect to Relay server and register."""
        if not self._relay_url:
            logger.error("[relay] HERMES_RELAY_URL not set")
            return False

        self._running = True
        asyncio.create_task(self._reconnect_loop())
        return True

    async def disconnect(self):
        self._running = False
        if self._ws:
            await self._ws.close()

    async def _reconnect_loop(self):
        while self._running:
            try:
                async with websockets.connect(self._relay_url) as ws:
                    self._ws = ws
                    # Register
                    msg = {"type": "register", "name": self._name}
                    if self._auth:
                        msg["auth"] = self._auth
                    await ws.send(json.dumps(msg))
                    logger.info(f"[relay] Registered as '{self._name}'")

                    async for raw in ws:
                        try:
                            data = json.loads(raw)
                        except json.JSONDecodeError:
                            continue
                        asyncio.create_task(self._handle_message(data))

            except Exception as e:
                logger.warning(f"[relay] Disconnected: {e}. Reconnecting in 5s...")
                await asyncio.sleep(5)

    async def _handle_message(self, msg: Dict[str, Any]):
        mtype = msg.get("type", "")
        if mtype != "chat":
            return

        app_id = msg.get("from", "")
        content = msg.get("content", "")
        chat_id = f"relay:{app_id}"

        # Process through Hermes agent
        try:
            result = await self.send_to_agent(chat_id, content)
            text = result.text if isinstance(result, SendResult) else str(result)

            if text and self._ws:
                # Stream response in chunks
                for i in range(0, len(text), 50):
                    chunk = text[i : i + 50]
                    await self._ws.send(json.dumps({
                        "type": "chunk",
                        "to": app_id,
                        "delta": chunk,
                    }))
                    await asyncio.sleep(0.03)
                await self._ws.send(json.dumps({"type": "done", "to": app_id}))
        except Exception as e:
            logger.error(f"[relay] Agent error: {e}")
            if self._ws:
                await self._ws.send(json.dumps({
                    "type": "chunk", "to": app_id,
                    "delta": f"Error: {e}",
                }))
                await self._ws.send(json.dumps({"type": "done", "to": app_id}))

    async def send_message(self, chat_id: str, text: str, **kwargs) -> SendResult:
        """Not used — Relay pushes to agent directly."""
        return SendResult(success=True)

    async def send_image(self, chat_id: str, image_url: str, caption: str = "", **kwargs) -> SendResult:
        return SendResult(success=False, error="Images not supported via Relay yet")
