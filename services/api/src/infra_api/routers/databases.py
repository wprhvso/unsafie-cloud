from fastapi import APIRouter, Depends
from infra_api.auth import get_current_user_login
from infra_api.schemas import DatabaseCreate, DatabaseResponse
from infra_api.services.db_provisioner import db_provisioner
from infra_db.models import DatabaseInstance, User
from infra_db.session import get_db_session
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

router = APIRouter(prefix="/api/databases", tags=["databases"])


@router.post("", response_model=DatabaseResponse)
async def order_database(
    payload: DatabaseCreate,
    login: str = Depends(get_current_user_login),
    session: AsyncSession = Depends(get_db_session),
):
    stmt = select(User).where(User.github_login == login)
    result = await session.execute(stmt)
    user = result.scalar_one_or_none()
    user_id = user.id if user else 1

    username, password, port, url = db_provisioner.generate_credentials(
        db_type=payload.db_type,
        db_name=payload.db_name,
        username=login,
    )

    db_instance = DatabaseInstance(
        user_id=user_id,
        db_type=payload.db_type,
        db_name=payload.db_name,
        db_user=username,
        password_hash=password,
        port=port,
        connection_url_cached=url,
        status="active",
    )
    session.add(db_instance)
    await session.commit()
    await session.refresh(db_instance)

    return DatabaseResponse(
        id=db_instance.id,
        db_type=db_instance.db_type,
        db_name=db_instance.db_name,
        db_user=db_instance.db_user,
        port=db_instance.port,
        connection_url=db_instance.connection_url_cached,
        status=db_instance.status,
    )


@router.get("", response_model=list[DatabaseResponse])
async def list_databases(
    _login: str = Depends(get_current_user_login), session: AsyncSession = Depends(get_db_session)
):
    stmt = select(DatabaseInstance)
    result = await session.execute(stmt)
    instances = result.scalars().all()
    return [
        DatabaseResponse(
            id=d.id,
            db_type=d.db_type,
            db_name=d.db_name,
            db_user=d.db_user,
            port=d.port,
            connection_url=d.connection_url_cached,
            status=d.status,
        )
        for d in instances
    ]
