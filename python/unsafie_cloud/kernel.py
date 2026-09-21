from unsafie_cloud.models import KernelResult


class KernelManager:
    def __init__(self, client):
        self.client = client

    async def upgrade(
        self,
        version: str,
        sha256: str,
        download_url: str,
    ) -> KernelResult:
        payload = {
            "version": version,
            "sha256": sha256,
            "download_url": download_url,
        }
        res = await self.client.rpc("kernel.upgrade", payload)
        changed = res.get("changed", True)
        data = res.get("result", {})
        if isinstance(data, dict):
            data["changed"] = changed
            return KernelResult.model_validate(data)
        return KernelResult(current_version=version, active_slot="slot_b", changed=changed)

    async def status(self) -> KernelResult:
        res = await self.client.rpc("kernel.status", {})
        data = res.get("result", {})
        if isinstance(data, dict):
            return KernelResult.model_validate(data)
        return KernelResult(current_version="0.1.0", active_slot="slot_a")
