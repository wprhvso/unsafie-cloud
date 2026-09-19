from decimal import Decimal

from infra_db.models import KvmVm, Plan, Tenant, User
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession


class QuotaService:
    @staticmethod
    async def validate_tenant_quota(
        session: AsyncSession, user: User, cpu: Decimal, ram_mb: int
    ) -> bool:
        if not user.plan_id:
            return True

        plan = await session.get(Plan, user.plan_id)
        if not plan:
            return True

        stmt = select(
            func.coalesce(func.sum(Tenant.cpu_limit_cores), Decimal("0")),
            func.coalesce(func.sum(Tenant.ram_limit_mb), 0),
        ).where(Tenant.user_id == user.id)

        result = await session.execute(stmt)
        used_cpu, used_ram = result.one()

        if (used_cpu + cpu) > Decimal(plan.max_vcpus):
            return False
        if (used_ram + ram_mb) > plan.max_ram_mb:
            return False
        return True

    @staticmethod
    async def validate_vm_quota(session: AsyncSession, user: User, vcpus: int, ram_mb: int) -> bool:
        if not user.plan_id:
            return True

        plan = await session.get(Plan, user.plan_id)
        if not plan:
            return True

        stmt = select(
            func.coalesce(func.sum(KvmVm.vcpus), 0),
            func.coalesce(func.sum(KvmVm.ram_mb), 0),
            func.count(KvmVm.id),
        ).where(KvmVm.user_id == user.id)

        result = await session.execute(stmt)
        used_vcpus, used_ram, vm_count = result.one()

        if (vm_count + 1) > plan.max_vms:
            return False
        if (used_vcpus + vcpus) > plan.max_vcpus:
            return False
        if (used_ram + ram_mb) > plan.max_ram_mb:
            return False
        return True


quota_service = QuotaService()
