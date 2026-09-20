from unsafie_cloud.models import NodeResult


class NodeManager:
    def __init__(self, client):
        self.client = client

    async def add(
        self,
        host: str,
        ssh_user: str = "root",
        ssh_key: str | None = None,
        port: int = 22,
    ) -> NodeResult:
        payload = {
            "host": host,
            "ssh_user": ssh_user,
            "ssh_key": ssh_key,
            "port": port,
        }
        res = await self.client.rpc("node.add", payload)
        changed = res.get("changed", True)
        data = res.get("result", {})
        if isinstance(data, dict):
            data["changed"] = changed
            return NodeResult.model_validate(data)
        return NodeResult(name=host, ip_address=host, changed=changed)

    async def list(self) -> list[NodeResult]:
        res = await self.client.rpc("node.list", {})
        items = res.get("result", [])
        if isinstance(items, list):
            return [NodeResult.model_validate(x) for x in items if isinstance(x, dict)]
        return []

    async def get(self, name: str) -> NodeResult:
        res = await self.client.rpc("node.get", {"name": name})
        data = res.get("result", {})
        if isinstance(data, dict):
            return NodeResult.model_validate(data)
        return NodeResult(name=name, ip_address="127.0.0.1")

    async def remove(self, name: str) -> bool:
        res = await self.client.rpc("node.remove", {"name": name})
        return res.get("status") == "ok"
