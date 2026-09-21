from typing import Any

from unsafie_cloud.models import ImageResult, VmResult


class VmManager:
    def __init__(self, client):
        self.client = client

    async def ensure(
        self,
        name: str,
        vcpus: int = 2,
        ram_mb: int = 4096,
        disk_gb: int = 30,
        image: str | None = None,
        iso: str | None = None,
        tasks: list[dict[str, Any]] | None = None,
        ssh_keys: list[str] | None = None,
    ) -> VmResult:
        payload = {
            "name": name,
            "vcpus": vcpus,
            "ram_mb": ram_mb,
            "disk_gb": disk_gb,
            "image": image,
            "iso": iso,
            "tasks": tasks or [],
            "ssh_keys": ssh_keys or [],
        }
        res = await self.client.rpc("vm.ensure", payload)
        changed = res.get("changed", False)
        data = res.get("result", {})
        if isinstance(data, dict):
            data["changed"] = changed
            return VmResult.model_validate(data)
        return VmResult(
            name=name,
            vcpus=vcpus,
            ram_mb=ram_mb,
            disk_gb=disk_gb,
            image=image,
            iso=iso,
            changed=changed,
        )

    async def get(self, name: str) -> VmResult:
        res = await self.client.rpc("vm.get", {"name": name})
        data = res.get("result", {})
        if isinstance(data, dict):
            return VmResult.model_validate(data)
        return VmResult(name=name, vcpus=2, ram_mb=4096, disk_gb=30, status="running")

    async def list(self) -> list[VmResult]:
        res = await self.client.rpc("vm.list", {})
        items = res.get("result", [])
        if isinstance(items, list):
            return [VmResult.model_validate(x) for x in items if isinstance(x, dict)]
        return []

    async def delete(self, name: str) -> bool:
        res = await self.client.rpc("vm.delete", {"name": name})
        return res.get("status") == "ok"

    async def start(self, name: str) -> bool:
        res = await self.client.rpc("vm.start", {"name": name})
        return res.get("status") == "ok"

    async def stop(self, name: str) -> bool:
        res = await self.client.rpc("vm.stop", {"name": name})
        return res.get("status") == "ok"

    async def reboot(self, name: str) -> bool:
        res = await self.client.rpc("vm.reboot", {"name": name})
        return res.get("status") == "ok"

    async def bake(self, name: str, image_name: str) -> ImageResult:
        res = await self.client.rpc("vm.bake", {"name": name, "image_name": image_name})
        data = res.get("result", {})
        if isinstance(data, dict):
            return ImageResult.model_validate(data)
        return ImageResult(name=image_name, status="ready")
