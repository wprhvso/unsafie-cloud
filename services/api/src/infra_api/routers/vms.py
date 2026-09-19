from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException
from infra_api.auth import get_current_user_login
from infra_api.schemas import VmCreate, VmResponse
from infra_api.services.quota_service import quota_service
from infra_db.models import KvmVm, User
from infra_db.session import get_db_session
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

router = APIRouter(prefix="/api/vms", tags=["vms"])


@router.post("", response_model=VmResponse)
async def create_vm(
    payload: VmCreate,
    login: str = Depends(get_current_user_login),
    session: AsyncSession = Depends(get_db_session),
):
    stmt = select(User).where(User.github_login == login)
    result = await session.execute(stmt)
    user = result.scalar_one_or_none()
    user_id = user.id if user else 1

    if user:
        allowed = await quota_service.validate_vm_quota(
            session, user, payload.vcpus, payload.ram_mb
        )
        if not allowed:
            raise HTTPException(status_code=400, detail="VM quota exceeded")

    vm = KvmVm(
        user_id=user_id,
        name=payload.name,
        node=payload.node,
        vcpus=payload.vcpus,
        ram_mb=payload.ram_mb,
        disk_gb=payload.disk_gb,
        ip_address="10.42.1.50",
        status="running",
    )
    session.add(vm)
    await session.commit()
    await session.refresh(vm)

    return VmResponse(
        id=vm.id,
        name=vm.name,
        node=vm.node,
        vcpus=vm.vcpus,
        ram_mb=vm.ram_mb,
        disk_gb=vm.disk_gb,
        ip_address=vm.ip_address,
        status=vm.status,
    )


@router.get("", response_model=list[VmResponse])
async def list_vms(
    _login: str = Depends(get_current_user_login), session: AsyncSession = Depends(get_db_session)
):
    stmt = select(KvmVm)
    result = await session.execute(stmt)
    vms = result.scalars().all()
    return [
        VmResponse(
            id=v.id,
            name=v.name,
            node=v.node,
            vcpus=v.vcpus,
            ram_mb=v.ram_mb,
            disk_gb=v.disk_gb,
            ip_address=v.ip_address,
            status=v.status,
        )
        for v in vms
    ]


@router.delete("/{vm_id}")
async def delete_vm(
    vm_id: UUID,
    _login: str = Depends(get_current_user_login),
    session: AsyncSession = Depends(get_db_session),
):
    vm = await session.get(KvmVm, vm_id)
    if not vm:
        raise HTTPException(status_code=404, detail="VM not found")
    await session.delete(vm)
    await session.commit()
    return {"status": "deleted", "id": str(vm_id)}
