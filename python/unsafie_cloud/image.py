from unsafie_cloud.models import ImageResult


class ImageManager:
    def __init__(self, client):
        self.client = client

    async def list(self) -> list[ImageResult]:
        res = await self.client.rpc("image.list", {})
        items = res.get("result", [])
        if isinstance(items, list):
            return [ImageResult.model_validate(x) for x in items if isinstance(x, dict)]
        return []

    async def delete(self, name: str) -> bool:
        res = await self.client.rpc("image.delete", {"name": name})
        return res.get("status") == "ok"
