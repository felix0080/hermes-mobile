#!/usr/bin/env python3
"""Hermes Relay — WebSocket broker for connecting apps to Hermes instances.

Usage:
    python3 relay.py                     # default :9920
    python3 relay.py --port 9920         # custom port
    python3 relay.py --auth secret       # require auth key

Protocol (JSON over WebSocket):
    # Hermes bridge → Relay
    {"type":"register","name":"我的Mac"}
    {"type":"chunk","to":"<app_id>","delta":"Hello"}
    {"type":"done","to":"<app_id>"}

    # App → Relay
    {"type":"list"}                        → {"type":"instances","list":[...]}
    {"type":"chat","target":"<hermes_id>","content":"hello"}
    
    # Relay → App
    {"type":"chunk","from":"<hermes_id>","delta":"Hello"}
    {"type":"done","from":"<hermes_id>"}
"""

import argparse
import asyncio
import json
import logging
import uuid
from typing import Dict, Optional

try:
    import websockets
    from websockets.server import WebSocketServerProtocol
except ImportError:
    print("Missing 'websockets' package. Install: pip install websockets")
    raise

logging.basicConfig(level=logging.INFO, format="%(asctime)s [relay] %(message)s")
logger = logging.getLogger("relay")


class Relay:
    def __init__(self, auth_key: str = ""):
        self._auth = auth_key
        self._hermes: Dict[str, dict] = {}   # hermes_id → {name, ws}
        self._apps: Dict[str, dict] = {}     # app_id → {ws}

    async def handle(self, ws: WebSocketServerProtocol):
        peer_id = str(uuid.uuid4())[:8]
        role = None  # "hermes" or "app"
        name = ""

        try:
            async for raw in ws:
                try:
                    msg = json.loads(raw)
                except json.JSONDecodeError:
                    continue

                mtype = msg.get("type", "")

                # Auth check
                if self._auth and msg.get("auth") != self._auth:
                    await ws.send(json.dumps({"type": "error", "message": "Invalid auth key"}))
                    continue

                # --- Hermes bridge registration ---
                if mtype == "register":
                    role = "hermes"
                    name = msg.get("name", peer_id)
                    self._hermes[peer_id] = {"name": name, "ws": ws}
                    logger.info(f"[+] Hermes registered: {name} ({peer_id})")
                    await self._broadcast_instances()

                # --- Hermes → App: streaming chunks ---
                elif mtype == "chunk" and role == "hermes":
                    target = msg.get("to", "")
                    if target in self._apps:
                        await self._apps[target]["ws"].send(json.dumps({
                            "type": "chunk",
                            "from": peer_id,
                            "delta": msg.get("delta", ""),
                        }))
                    else:
                        logger.warning(f"App {target} not found")

                elif mtype == "done" and role == "hermes":
                    target = msg.get("to", "")
                    if target in self._apps:
                        await self._apps[target]["ws"].send(json.dumps({
                            "type": "done",
                            "from": peer_id,
                        }))

                # --- App: list instances ---
                elif mtype == "list":
                    role = "app"
                    self._apps[peer_id] = {"ws": ws}
                    await self._broadcast_instances(ws)

                # --- App: send chat ---
                elif mtype == "chat":
                    role = "app"
                    self._apps[peer_id] = {"ws": ws}
                    target = msg.get("target", "")
                    if target in self._hermes:
                        await self._hermes[target]["ws"].send(json.dumps({
                            "type": "chat",
                            "from": peer_id,
                            "content": msg.get("content", ""),
                        }))
                    else:
                        await ws.send(json.dumps({
                            "type": "error",
                            "message": f"Instance '{target}' not found",
                        }))

        except websockets.ConnectionClosed:
            pass
        finally:
            if role == "hermes":
                removed = self._hermes.pop(peer_id, None)
                if removed:
                    logger.info(f"[-] Hermes disconnected: {removed['name']}")
            elif role == "app":
                self._apps.pop(peer_id, None)
            await self._broadcast_instances()

    async def _broadcast_instances(self, target: Optional[WebSocketServerProtocol] = None):
        """Send instance list to all apps, or to a specific app."""
        payload = json.dumps({
            "type": "instances",
            "list": [
                {"id": hid, "name": info["name"]}
                for hid, info in self._hermes.items()
            ],
        })
        if target:
            await target.send(payload)
        else:
            for info in self._apps.values():
                try:
                    await info["ws"].send(payload)
                except websockets.ConnectionClosed:
                    pass


async def main():
    parser = argparse.ArgumentParser(description="Hermes Relay Server")
    parser.add_argument("--port", type=int, default=9920)
    parser.add_argument("--auth", type=str, default="")
    parser.add_argument("--host", type=str, default="0.0.0.0")
    args = parser.parse_args()

    relay = Relay(auth_key=args.auth)

    logger.info(f"Relay listening on {args.host}:{args.port}")
    if args.auth:
        logger.info(f"Auth key: {args.auth}")

    async with websockets.serve(relay.handle, args.host, args.port):
        await asyncio.Future()  # run forever


if __name__ == "__main__":
    asyncio.run(main())
