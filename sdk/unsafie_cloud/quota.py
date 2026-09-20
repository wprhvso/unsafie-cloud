from unsafie_cloud.models import QuotaResult


class QuotaManager:
    def __init__(self, client):
        self.client = client

    async def ensure(
        self,
        owner: str,
        max_vcpus: int,
        max_ram_mb: int,
        max_disk_gb: int,
        max_vms: int = 5,
    ) -> QuotaResult:
        payload = {
            "owner": owner,
            "max_vcpus": max_vcpus,
            "max_ram_mb": max_ram_mb,
            "max_disk_gb": max_disk_gb,
            "max_vms": max_vms,
        }
        res = await self.client.rpc("quota.ensure", payload)
        changed = res.get("changed", False)
        data = res.get("result", {})
        if isinstance(data, dict):
            data["changed"] = changed
            return QuotaResult.model_validate(data)
        return QuotaResult(
            owner=owner,
            max_vcpus=max_vcpus,
            max_ram_mb=max_ram_mb,
            max_disk_gb=max_disk_gb,
            max_vms=max_vms,
            changed=changed,
        )

    async def get(self, owner: str) -> QuotaResult:
        res = await self.client.rpc("quota.get", {"owner": owner})
        data = res.get("result", {})
        if isinstance(data, dict):
            return QuotaResult.model_validate(data)
        return QuotaResult(owner=owner, max_vcpus=4, max_ram_mb=8192, max_disk_gb=50, max_vms=2)
