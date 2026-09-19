import secrets
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Response
from infra_api.auth import get_current_user_login
from infra_api.schemas import S3BucketCreate, S3BucketResponse
from infra_db.models import S3Bucket, User
from infra_db.session import get_db_session
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

router = APIRouter(prefix="/api/storage", tags=["storage"])


@router.post("/buckets", response_model=S3BucketResponse)
async def create_s3_bucket(
    payload: S3BucketCreate,
    login: str = Depends(get_current_user_login),
    session: AsyncSession = Depends(get_db_session),
):
    stmt = select(User).where(User.github_login == login)
    result = await session.execute(stmt)
    user = result.scalar_one_or_none()
    user_id = user.id if user else 1

    access_key = f"GK{secrets.token_hex(11)}"
    secret_key = secrets.token_hex(32)

    bucket = S3Bucket(
        user_id=user_id,
        bucket_name=payload.bucket_name,
        bucket_type=payload.bucket_type,
        quota_gb=payload.quota_gb,
        access_key_id=access_key,
        secret_access_key=secret_key,
        status="active",
    )
    session.add(bucket)
    await session.commit()
    await session.refresh(bucket)

    return S3BucketResponse(
        id=bucket.id,
        bucket_name=bucket.bucket_name,
        bucket_type=bucket.bucket_type,
        quota_gb=bucket.quota_gb,
        access_key_id=bucket.access_key_id,
        status=bucket.status,
    )


@router.get("/buckets", response_model=list[S3BucketResponse])
async def list_s3_buckets(
    _login: str = Depends(get_current_user_login), session: AsyncSession = Depends(get_db_session)
):
    stmt = select(S3Bucket)
    result = await session.execute(stmt)
    buckets = result.scalars().all()
    return [
        S3BucketResponse(
            id=b.id,
            bucket_name=b.bucket_name,
            bucket_type=b.bucket_type,
            quota_gb=b.quota_gb,
            access_key_id=b.access_key_id,
            status=b.status,
        )
        for b in buckets
    ]


@router.get("/buckets/{bucket_id}/cyberduck-profile")
async def get_cyberduck_profile(
    bucket_id: UUID,
    _login: str = Depends(get_current_user_login),
    session: AsyncSession = Depends(get_db_session),
):
    bucket = await session.get(S3Bucket, bucket_id)
    if not bucket:
        raise HTTPException(status_code=404, detail="Bucket not found")

    content = f"""<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Protocol</key>
    <string>s3</string>
    <key>Vendor</key>
    <string>S3</string>
    <key>Hostname</key>
    <string>s3.example.com</string>
    <key>Port</key>
    <string>443</string>
    <key>Username</key>
    <string>{bucket.access_key_id}</string>
    <key>Default Path</key>
    <string>/{bucket.bucket_name}</string>
</dict>
</plist>"""
    return Response(
        content=content,
        media_type="application/octet-stream",
        headers={
            "Content-Disposition": f"attachment; filename={bucket.bucket_name}.cyberduckprofile"
        },
    )
