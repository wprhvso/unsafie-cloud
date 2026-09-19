from fastapi import APIRouter, Depends
from infra_api.auth import get_current_user_login

router = APIRouter(prefix="/api/dashboard", tags=["dashboard"])


@router.get("/stats")
async def get_dashboard_stats(_login: str = Depends(get_current_user_login)):
    return {
        "nodes_online": 3,
        "active_vms": 2,
        "active_tenants": 4,
        "active_databases": 11,
        "active_kameleo_slots": 1,
        "max_kameleo_slots": 10,
    }


@router.get("/quotas")
async def get_user_quotas(_login: str = Depends(get_current_user_login)):
    return {
        "vcpus_used": 2,
        "vcpus_limit": 4,
        "ram_mb_used": 4096,
        "ram_mb_limit": 8192,
        "disk_gb_used": 25,
        "disk_gb_limit": 60,
        "domains_used": 1,
        "domains_limit": 6,
    }
