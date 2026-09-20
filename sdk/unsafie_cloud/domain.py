
from unsafie_cloud.models import DomainResult


class DomainManager:
    def __init__(self, client):
        self.client = client

    async def ensure(
        self,
        fqdn: str,
        target_vm: str,
        target_port: int = 80,
        ssl_cert: str | None = None,
        ssl_key: str | None = None,
    ) -> DomainResult:
        payload = {
            "fqdn": fqdn,
            "target_vm": target_vm,
            "target_port": target_port,
            "ssl_cert_pem": ssl_cert,
            "ssl_key_pem": ssl_key,
        }
        res = await self.client.rpc("domain.ensure", payload)
        changed = res.get("changed", False)
        data = res.get("result", {})
        if isinstance(data, dict):
            data["changed"] = changed
            return DomainResult.model_validate(data)
        return DomainResult(
            fqdn=fqdn,
            target_vm=target_vm,
            target_port=target_port,
            changed=changed,
        )

    async def delete(self, fqdn: str) -> bool:
        res = await self.client.rpc("domain.delete", {"fqdn": fqdn})
        return res.get("status") == "ok"
