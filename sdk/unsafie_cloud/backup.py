from unsafie_cloud.models import BackupResult


class BackupManager:
    def __init__(self, client):
        self.client = client

    async def create(self, name: str) -> BackupResult:
        res = await self.client.rpc("backup.create", {"name": name})
        data = res.get("result", {})
        if isinstance(data, dict):
            return BackupResult.model_validate(data)
        return BackupResult(name=name, url="r2://backups/" + name, created_at="now")

    async def restore(self, backup_url: str) -> bool:
        res = await self.client.rpc("backup.restore", {"url": backup_url})
        return res.get("status") == "ok"

    async def list(self) -> list[BackupResult]:
        res = await self.client.rpc("backup.list", {})
        items = res.get("result", [])
        if isinstance(items, list):
            return [BackupResult.model_validate(x) for x in items if isinstance(x, dict)]
        return []
