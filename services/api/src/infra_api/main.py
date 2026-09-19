from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from infra_api.routers.api_keys import router as api_keys_router
from infra_api.routers.auth import router as auth_router
from infra_api.routers.dashboard import router as dashboard_router
from infra_api.routers.databases import router as databases_router
from infra_api.routers.gateway import router as gateway_router
from infra_api.routers.storage import router as storage_router
from infra_api.routers.tenants import router as tenants_router
from infra_api.routers.vms import router as vms_router

app = FastAPI(
    title="Infrastructure Platform API",
    version="0.1.0",
    docs_url="/docs",
    redoc_url="/redoc",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth_router)
app.include_router(dashboard_router)
app.include_router(tenants_router)
app.include_router(vms_router)
app.include_router(databases_router)
app.include_router(storage_router)
app.include_router(api_keys_router)
app.include_router(gateway_router)


@app.get("/healthz")
async def healthz():
    return {"status": "ok", "version": "0.1.0"}


@app.get("/")
async def root():
    return {"message": "Infrastructure Platform API", "docs": "/docs"}
