import httpx
from infra_api.config import settings


class CloudflareService:
    def __init__(self) -> None:
        self.api_token = settings.CLOUDFLARE_API_TOKEN
        self.zone_id = settings.CLOUDFLARE_ZONE_ID
        self.base_url = "https://api.cloudflare.com/client/v4"

    async def create_cname_record(self, name: str, target: str, ttl: int = 300) -> str:
        if not self.api_token or not self.zone_id:
            return "simulated_cf_record_id"

        headers = {
            "Authorization": f"Bearer {self.api_token}",
            "Content-Type": "application/json",
        }
        payload = {
            "type": "CNAME",
            "name": name,
            "content": target,
            "ttl": ttl,
            "proxied": False,
        }
        async with httpx.AsyncClient() as client:
            resp = await client.post(
                f"{self.base_url}/zones/{self.zone_id}/dns_records",
                headers=headers,
                json=payload,
                timeout=10.0,
            )
            data = resp.json()
            if not data.get("success"):
                raise RuntimeError(f"Cloudflare API error: {data.get('errors')}")
            return str(data["result"]["id"])

    async def delete_dns_record(self, record_id: str) -> bool:
        if not self.api_token or not self.zone_id or record_id.startswith("simulated"):
            return True

        headers = {"Authorization": f"Bearer {self.api_token}"}
        async with httpx.AsyncClient() as client:
            resp = await client.delete(
                f"{self.base_url}/zones/{self.zone_id}/dns_records/{record_id}",
                headers=headers,
                timeout=10.0,
            )
            return resp.status_code == 200


cloudflare_service = CloudflareService()
