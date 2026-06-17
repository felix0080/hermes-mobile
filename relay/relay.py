#!/usr/bin/env python3
"""Hermes Relay — WebSocket broker (websockets 16.0 compatible).

Usage:
    python3.11 relay.py --port 9920
"""

import argparse
import asyncio
import json
import logging
import uuid
from typing import Optional

from websockets.asyncio.server import serve, ServerConnection

logging.basicConfig(level=logging.INFO, format="%(asctime)s [relay] %(message)s")
logger = logging.getLogger("relay")


class Relay:
    def __init__(self, auth_key: str = ""):
        self._auth = auth_key
        self._hermes = {}   # hermes_id → {name, ws}
        self._apps = {}     # app_id → {ws}

    async def handle(self, ws: ServerConnection):
        peer_id = str(uuid.uuid4())[:8]
        role = None

        try:
            async for raw in ws:
                try:
                    msg = json.loads(raw)
                except json.JSONDecodeError:
                    continue

                mtype = msg.get("type", "")
                if self._auth and msg.get("auth") != self._auth:
                    await ws.send(json.dumps({"type": "error", "message": "Invalid auth"}))
                    continue

                if mtype == "register":
                    role = "hermes"
                    name = msg.get("name", peer_id)
                    self._hermes[peer_id] = {"name": name, "ws": ws}
                    logger.info(f"[+] {name} ({peer_id})")
                    await self._broadcast()

                elif mtype == "chunk" and role == "hermes":
                    target = msg.get("to", "")
                    if target in self._apps:
                        await self._apps[target]["ws"].send(json.dumps({
                            "type": "chunk", "from": peer_id, "delta": msg.get("delta", ""),
                        }))

                elif mtype == "done" and role == "hermes":
                    target = msg.get("to", "")
                    if target in self._apps:
                        await self._apps[target]["ws"].send(json.dumps({
                            "type": "done", "from": peer_id,
                        }))

                elif mtype == "list":
                    role = "app"
                    self._apps[peer_id] = {"ws": ws}
                    await self._broadcast(ws)

                elif mtype == "chat":
                    role = "app"
                    self._apps[peer_id] = {"ws": ws}
                    target = msg.get("target", "")
                    if target in self._hermes:
                        await self._hermes[target]["ws"].send(json.dumps({
                            "type": "chat", "from": peer_id, "content": msg.get("content", ""),
                        }))
                    else:
                        await ws.send(json.dumps({"type": "error", "message": "Instance not found"}))

        except Exception:
            pass
        finally:
            if role == "hermes":
                removed = self._hermes.pop(peer_id, None)
                if removed:
                    logger.info(f"[-] {removed['name']}")
            elif role == "app":
                self._apps.pop(peer_id, None)
            await self._broadcast()

    async def _broadcast(self, target=None):
        payload = json.dumps({
            "type": "instances",
            "list": [{"id": hid, "name": info["name"]} for hid, info in self._hermes.items()],
        })
        if target:
            try:
                await target.send(payload)
            except Exception:
                pass
        else:
            for info in list(self._apps.values()):
                try:
                    await info["ws"].send(payload)
                except Exception:
                    pass


async def main():
    p = argparse.ArgumentParser(description="Hermes Relay")
    p.add_argument("--port", type=int, default=9920)
    p.add_argument("--auth", type=str, default="")
    p.add_argument("--host", type=str, default="0.0.0.0")
    args = p.parse_args()

    relay = Relay(auth_key=args.auth)
    logger.info(f"Relay on {args.host}:{args.port}")
    async with serve(relay.handle, args.host, args.port):
        await asyncio.Future()


if __name__ == "__main__":
    asyncio.run(main())
