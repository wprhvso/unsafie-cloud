from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException
from infra_api.auth import get_current_user_login
from infra_api.schemas import ApiKeyCreate, ApiKeyCreated, ApiKeyResponse
from infra_api.services.api_key_service import api_key_service
from infra_db.models import ApiKey, User
from infra_db.session import get_db_session
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

router = APIRouter(prefix="/api/api-keys", tags=["api_keys"])


@router.post("", response_model=ApiKeyCreated)
async def create_api_key(
    payload: ApiKeyCreate,
    login: str = Depends(get_current_user_login),
    session: AsyncSession = Depends(get_db_session),
):
    stmt = select(User).where(User.github_login == login)
    result = await session.execute(stmt)
    user = result.scalar_one_or_none()
    user_id = user.id if user else 1

    full_key, key_prefix, key_hash = api_key_service.generate_api_key()

    api_key = ApiKey(
        user_id=user_id,
        name=payload.name,
        key_prefix=key_prefix,
        key_hash=key_hash,
        scopes=payload.scopes,
    )
    session.add(api_key)
    await session.commit()
    await session.refresh(api_key)

    return ApiKeyCreated(
        id=api_key.id,
        name=api_key.name,
        key_prefix=api_key.key_prefix,
        scopes=api_key.scopes,
        is_revoked=api_key.is_revoked,
        created_at=api_key.created_at,
        secret_key=full_key,
    )


@router.get("", response_model=list[ApiKeyResponse])
async def list_api_keys(
    _login: str = Depends(get_current_user_login), session: AsyncSession = Depends(get_db_session)
):
    stmt = select(ApiKey)
    result = await session.execute(stmt)
    keys = result.scalars().all()
    return [
        ApiKeyResponse(
            id=k.id,
            name=k.name,
            key_prefix=k.key_prefix,
            scopes=k.scopes,
            is_revoked=k.is_revoked,
            created_at=k.created_at,
        )
        for k in keys
    ]


@router.delete("/{key_id}")
async def revoke_api_key(
    key_id: UUID,
    _login: str = Depends(get_current_user_login),
    session: AsyncSession = Depends(get_db_session),
):
    key = await session.get(ApiKey, key_id)
    if not key:
        raise HTTPException(status_code=404, detail="Key not found")
    key.is_revoked = True
    await session.commit()
    return {"status": "revoked", "id": str(key_id)}
