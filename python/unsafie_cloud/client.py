import asyncio
import json
import os
import uuid
from typing import Any

import httpx
import websockets
from websockets.exceptions import WebSocketException

from unsafie_cloud.backup import BackupManager
from unsafie_cloud.domain import DomainManager
from unsafie_cloud.exceptions import (
    AuthError,
    ConflictError,
    ForbiddenError,
    NotFoundError,
    UnsafieCloudError,
)
from unsafie_cloud.grant import GrantManager
from unsafie_cloud.image import ImageManager
from unsafie_cloud.iso import IsoManager
from unsafie_cloud.kernel import KernelManager
from unsafie_cloud.node import NodeManager
from unsafie_cloud.port import PortManager
from unsafie_cloud.quota import QuotaManager
from unsafie_cloud.token import TokenManager
from unsafie_cloud.vm import VmManager


class Client:
    def __init__(
        self,
        endpoint: str | None = None,
        api_key: str | None = None,
    ):
        self.endpoint = (
            endpoint or os.environ.get("UNSAFIE_ENDPOINT") or "https://127.0.0.1:443"
        ).rstrip("/")
        self.api_key = (
            api_key
            or os.environ.get("UNSAFIE_API_KEY")
            or os.environ.get("UNSAFIE_ADMIN_TOKEN")
            or ""
        )

        self.vm = VmManager(self)
        self.iso = IsoManager(self)
        self.image = ImageManager(self)
        self.port = PortManager(self)
        self.domain = DomainManager(self)
        self.token = TokenManager(self)
        self.grant = GrantManager(self)
        self.quota = QuotaManager(self)
        self.node = NodeManager(self)
        self.kernel = KernelManager(self)
        self.backup = BackupManager(self)

        self._ws: Any | None = None
        self._http_client: httpx.AsyncClient | None = None

    async def __aenter__(self):
        await self.connect()
        return self

    async def __aexit__(self, exc_type, exc_val, exc_tb):
        await self.close()

    async def connect(self):
        ws_url = self.endpoint.replace("http://", "ws://").replace("https://", "wss://")
        if not ws_url.endswith("/ws") and not ws_url.endswith("/ws/v1"):
            ws_url = f"{ws_url}/ws/v1"
        try:
            self._ws = await websockets.connect(
                ws_url,
                subprotocols=["unsafie-rpc"],
                ping_interval=15,
                ping_timeout=20,
            )
            auth_frame = {
                "id": str(uuid.uuid4()),
                "action": "auth",
                "token": self.api_key,
            }
            await self._ws.send(json.dumps(auth_frame))
        except (WebSocketException, OSError, TimeoutError):
            self._ws = None

        if self._http_client is None:
            self._http_client = httpx.AsyncClient(
                base_url=self.endpoint,
                headers={"Authorization": f"Bearer {self.api_key}"},
                timeout=30.0,
                verify=False,
            )

    async def close(self):
        if self._ws:
            await self._ws.close()
            self._ws = None
        if self._http_client:
            await self._http_client.aclose()
            self._http_client = None

    async def rpc(self, action: str, params: dict[str, Any]) -> dict[str, Any]:
        req_id = str(uuid.uuid4())
        frame = {
            "id": req_id,
            "action": action,
            "params": params,
        }

        if self._ws:
            try:
                await self._ws.send(json.dumps(frame))
                raw = await asyncio.wait_for(self._ws.recv(), timeout=25.0)
                data = json.loads(raw)
                if data.get("status") == "error":
                    self._raise_error(data)
                return data
            except (WebSocketException, OSError, TimeoutError):
                self._ws = None

        if not self._http_client:
            self._http_client = httpx.AsyncClient(
                base_url=self.endpoint,
                headers={"Authorization": f"Bearer {self.api_key}"},
                timeout=30.0,
                verify=False,
            )

        resp = await self._http_client.post(f"/v1/{action}", json=params)
        if resp.status_code == 401:
            raise AuthError("Unauthorized")
        if resp.status_code == 403:
            raise ForbiddenError(resp.text)
        if resp.status_code == 404:
            raise NotFoundError(resp.text)
        if resp.status_code == 409:
            raise ConflictError(resp.text)
        if resp.is_error:
            raise UnsafieCloudError(f"HTTP {resp.status_code}: {resp.text}")

        return resp.json()

    def _raise_error(self, data: dict[str, Any]):
        code = data.get("code", "")
        msg = data.get("error_message") or data.get("detail") or "RPC error"
        if code == "UNAUTHORIZED":
            raise AuthError(msg)
        if code == "FORBIDDEN" or code == "ACCESS_DENIED":
            raise ForbiddenError(msg)
        if code == "NOT_FOUND":
            raise NotFoundError(msg)
        if code == "CONFLICT":
            raise ConflictError(msg)
        raise UnsafieCloudError(f"{code}: {msg}")
