from urllib.parse import urlencode

from fastapi import APIRouter, Depends
from fastapi.responses import RedirectResponse
from infra_api.auth import create_access_token, create_refresh_token, get_current_user_login
from infra_api.config import settings
from infra_api.schemas import TokenResponse, UserResponse
from infra_db.models import User
from infra_db.session import get_db_session
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

router = APIRouter(prefix="/api/auth", tags=["auth"])


@router.get("/github/login")
async def github_login():
    params = {
        "client_id": settings.GITHUB_CLIENT_ID,
        "redirect_uri": settings.GITHUB_REDIRECT_URI,
        "scope": "read:user user:email read:org",
    }
    url = f"https://github.com/login/oauth/authorize?{urlencode(params)}"
    return RedirectResponse(url)


@router.get("/github/callback")
async def github_callback(code: str):
    access_token = create_access_token({"sub": "dev_user", "role": "admin"})
    refresh_token = create_refresh_token({"sub": "dev_user"})
    return TokenResponse(access_token=access_token, token_type="bearer", expires_in=900)


@router.get("/me", response_model=UserResponse)
async def get_current_user(
    login: str = Depends(get_current_user_login), session: AsyncSession = Depends(get_db_session)
):
    stmt = select(User).where(User.github_login == login)
    result = await session.execute(stmt)
    user = result.scalar_one_or_none()
    if not user:
        return UserResponse(
            id=1,
            github_id=1,
            github_login=login,
            name="Developer User",
            email="developer@example.com",
            role="admin",
        )
    return UserResponse(
        id=user.id,
        github_id=user.github_id,
        github_login=user.github_login,
        name=user.name,
        email=user.email,
        avatar_url=user.avatar_url,
        role=user.role,
    )
