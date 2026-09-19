from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException
from infra_api.auth import get_current_user_login
from infra_api.config import settings
from infra_api.schemas import TenantCreate, TenantResponse
from infra_api.services.cloudflare_service import cloudflare_service
from infra_api.services.quota_service import quota_service
from infra_db.models import Tenant, User
from infra_db.session import get_db_session
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

router = APIRouter(prefix="/api/tenants", tags=["tenants"])


@router.post("", response_model=TenantResponse)
async def create_tenant(
    payload: TenantCreate,
    login: str = Depends(get_current_user_login),
    session: AsyncSession = Depends(get_db_session),
):
    stmt = select(User).where(User.github_login == login)
    result = await session.execute(stmt)
    user = result.scalar_one_or_none()
    user_id = user.id if user else 1

    if user:
        allowed = await quota_service.validate_tenant_quota(
            session, user, payload.cpu_limit_cores, payload.ram_limit_mb
        )
        if not allowed:
            raise HTTPException(status_code=400, detail="Tenant quota exceeded")

    domains = []
    if payload.subdomain:
        full_domain = f"{payload.subdomain}.app.{settings.BASE_DOMAIN}"
        domains.append(full_domain)
        if payload.wildcard:
            domains.append(f"*.{full_domain}")
        await cloudflare_service.create_cname_record(
            name=f"{payload.subdomain}.app", target=settings.BASE_DOMAIN
        )

    tenant = Tenant(
        user_id=user_id,
        name=payload.name,
        kind=payload.kind,
        cpu_limit_cores=payload.cpu_limit_cores,
        ram_limit_mb=payload.ram_limit_mb,
        storage_limit_gb=payload.storage_limit_gb,
        domains=domains,
        status="active",
    )
    session.add(tenant)
    await session.commit()
    await session.refresh(tenant)

    return TenantResponse(
        id=tenant.id,
        name=tenant.name,
        kind=tenant.kind,
        cpu_limit_cores=tenant.cpu_limit_cores,
        ram_limit_mb=tenant.ram_limit_mb,
        storage_limit_gb=tenant.storage_limit_gb,
        domains=tenant.domains,
        status=tenant.status,
    )


@router.get("", response_model=list[TenantResponse])
async def list_tenants(
    _login: str = Depends(get_current_user_login), session: AsyncSession = Depends(get_db_session)
):
    stmt = select(Tenant)
    result = await session.execute(stmt)
    tenants = result.scalars().all()
    return [
        TenantResponse(
            id=t.id,
            name=t.name,
            kind=t.kind,
            cpu_limit_cores=t.cpu_limit_cores,
            ram_limit_mb=t.ram_limit_mb,
            storage_limit_gb=t.storage_limit_gb,
            domains=t.domains,
            status=t.status,
        )
        for t in tenants
    ]


@router.get("/{tenant_id}/kubeconfig")
async def get_tenant_kubeconfig(tenant_id: UUID, _login: str = Depends(get_current_user_login)):
    return {
        "tenant_id": str(tenant_id),
        "kubeconfig": "apiVersion: v1\nkind: Config\nclusters: []\ncontexts: []\nusers: []",
    }
