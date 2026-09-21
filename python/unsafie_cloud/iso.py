from unsafie_cloud.models import IsoResult


class IsoManager:
    def __init__(self, client):
        self.client = client

    async def ensure(
        self,
        name: str,
        url: str | None = None,
        is_shared: bool = False,
    ) -> IsoResult:
        payload = {
            "name": name,
            "url": url,
            "is_shared": is_shared,
        }
        res = await self.client.rpc("iso.ensure", payload)
        changed = res.get("changed", False)
        data = res.get("result", {})
        if isinstance(data, dict):
            data["changed"] = changed
            return IsoResult.model_validate(data)
        return IsoResult(name=name, is_shared=is_shared, source_url=url, changed=changed)

    async def list(self) -> list[IsoResult]:
        res = await self.client.rpc("iso.list", {})
        items = res.get("result", [])
        if isinstance(items, list):
            return [IsoResult.model_validate(x) for x in items if isinstance(x, dict)]
        return []

    async def delete(self, name: str) -> bool:
        res = await self.client.rpc("iso.delete", {"name": name})
        return res.get("status") == "ok"
