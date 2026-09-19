import pytest
from httpx import ASGITransport, AsyncClient
from infra_api.main import app
from infra_api.services.api_key_service import api_key_service
from infra_api.services.db_provisioner import db_provisioner


@pytest.mark.asyncio
async def test_healthz_endpoint():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        resp = await client.get("/healthz")
        assert resp.status_code == 200
        data = resp.json()
        assert data["status"] == "ok"
        assert data["version"] == "0.1.0"


@pytest.mark.asyncio
async def test_root_endpoint():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        resp = await client.get("/")
        assert resp.status_code == 200
        assert "Infrastructure Platform API" in resp.json()["message"]


@pytest.mark.asyncio
async def test_gateway_unauthorized():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        resp = await client.post("/v1/chat/completions")
        assert resp.status_code == 401


@pytest.mark.asyncio
async def test_gateway_authorized():
    transport = ASGITransport(app=app)
    headers = {"Authorization": "Bearer live_test_secret_key_123"}
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        resp = await client.post("/v1/chat/completions", headers=headers)
        assert resp.status_code == 200
        data = resp.json()
        assert data["object"] == "chat.completion"


@pytest.mark.asyncio
async def test_browser_gateway_session():
    transport = ASGITransport(app=app)
    headers = {"Authorization": "Bearer live_test_secret_key_123"}
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        resp = await client.post("/browser/v1/sessions", headers=headers)
        assert resp.status_code == 200
        data = resp.json()
        assert "ws_endpoint" in data
        assert data["status"] == "ready"


def test_api_key_service():
    full_key, prefix, key_hash = api_key_service.generate_api_key()
    assert full_key.startswith(prefix)
    assert api_key_service.verify_api_key(full_key, key_hash) is True
    assert api_key_service.verify_api_key("wrong_key", key_hash) is False


def test_db_provisioner():
    username, password, port, url = db_provisioner.generate_credentials(
        "postgres", "test_db", "user1"
    )
    assert port == 5432
    assert "postgresql://user1:" in url
    assert "/test_db" in url

    username, password, port, url = db_provisioner.generate_credentials("valkey", "cache", "user1")
    assert port == 6379
    assert "redis://:" in url
