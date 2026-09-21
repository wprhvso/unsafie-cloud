from unsafie_cloud.models import TokenResult


class TokenManager:
    def __init__(self, client):
        self.client = client

    async def ensure(
        self,
        name: str,
        owner: str,
        scopes: list[str] | None = None,
    ) -> TokenResult:
        payload = {
            "name": name,
            "owner": owner,
            "scopes": scopes or ["*"],
        }
        res = await self.client.rpc("token.ensure", payload)
        changed = res.get("changed", False)
        data = res.get("result", {})
        if isinstance(data, dict):
            data["changed"] = changed
            return TokenResult.model_validate(data)
        return TokenResult(
            name=name,
            owner=owner,
            key_prefix="phx_live_",
            secret_key="phx_live_placeholder",
            changed=changed,
        )

    async def revoke(self, name: str) -> bool:
        res = await self.client.rpc("token.revoke", {"name": name})
        return res.get("status") == "ok"
