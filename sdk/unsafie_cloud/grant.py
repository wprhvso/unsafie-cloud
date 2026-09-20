from unsafie_cloud.models import GrantResult


class GrantManager:
    def __init__(self, client):
        self.client = client

    async def port(
        self,
        owner: str,
        node: str,
        host_port: int,
        protocol: str = "tcp",
    ) -> GrantResult:
        payload = {
            "owner": owner,
            "node": node,
            "protocol": protocol,
            "host_port": host_port,
        }
        res = await self.client.rpc("admin.grant_port", payload)
        return GrantResult(
            status=res.get("status", "ok"),
            owner=owner,
            granted_resource=f"{node}:{protocol}:{host_port}",
            changed=True,
        )

    async def domain(self, owner: str, fqdn: str) -> GrantResult:
        payload = {
            "owner": owner,
            "fqdn": fqdn,
        }
        res = await self.client.rpc("admin.grant_domain", payload)
        return GrantResult(
            status=res.get("status", "ok"),
            owner=owner,
            granted_resource=fqdn,
            changed=True,
        )
