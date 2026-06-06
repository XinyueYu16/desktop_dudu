"""
Quick test: connects to the backend server, sends a poke, prints the response.
Run this AFTER starting server.py to verify WebSocket works.
"""
import asyncio
import json
from websockets.asyncio.client import connect


async def main():
    async with connect("ws://127.0.0.1:9876") as ws:
        # Send a poke
        await ws.send(json.dumps({
            "type": "pet.poke",
            "id": "test",
            "timestamp": 0,
            "payload": {}
        }))
        print("Sent: pet.poke")

        # Wait for response
        resp = await ws.recv()
        print(f"Got: {resp}")

        # Send a ping
        await ws.send(json.dumps({"type": "ping", "id": "test", "timestamp": 0, "payload": {}}))
        resp = await ws.recv()
        print(f"Pong: {resp}")


asyncio.run(main())
