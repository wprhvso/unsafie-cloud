from unsafie_cloud.models import PortResult


class PortManager:
    def __init__(self, client):
        self.client = client

    async def ensure(
        self,
        node: str,
        host_port: int,
        target_vm: str,
        target_port: int,
        protocol: str = "tcp",
    ) -> PortResult:
        payload = {
            "node": node,
            "host_port": host_port,
            "target_vm": target_vm,
            "target_port": target_port,
            "protocol": protocol,
        }
        res = await self.client.rpc("port.ensure", payload)
        changed = res.get("changed", False)
        data = res.get("result", {})
        if isinstance(data, dict):
            data["changed"] = changed
            return PortResult.model_validate(data)
        return PortResult(
            node=node,
            protocol=protocol,
            host_port=host_port,
            target_vm=target_vm,
            target_port=target_port,
            changed=changed,
        )

    async def delete(self, node: str, host_port: int, protocol: str = "tcp") -> bool:
        res = await self.client.rpc(
            "port.delete", {"node": node, "host_port": host_port, "protocol": protocol}
        )
        return res.get("status") == "ok"
