from __future__ import annotations

from datetime import datetime
from typing import Any
from uuid import UUID, uuid4

from sqlalchemy import DateTime, ForeignKey, Integer, String, Text, func
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column, relationship

from infra_db.base import Base


class DatabaseInstance(Base):
    __tablename__ = "databases_instances"

    id: Mapped[UUID] = mapped_column(primary_key=True, default=uuid4)
    user_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    db_type: Mapped[str] = mapped_column(String(32), nullable=False, index=True)
    db_name: Mapped[str] = mapped_column(String(64), nullable=False)
    db_user: Mapped[str] = mapped_column(String(64), nullable=False)
    password_hash: Mapped[str] = mapped_column(String(255), nullable=False)
    port: Mapped[int] = mapped_column(Integer, nullable=False)
    acl_rules: Mapped[dict[str, Any] | None] = mapped_column(JSONB, nullable=True)
    connection_url_cached: Mapped[str | None] = mapped_column(Text, nullable=True)
    status: Mapped[str] = mapped_column(String(32), default="active", index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    user: Mapped[User] = relationship("User", back_populates="databases")


class S3Bucket(Base):
    __tablename__ = "s3_buckets"

    id: Mapped[UUID] = mapped_column(primary_key=True, default=uuid4)
    user_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    bucket_name: Mapped[str] = mapped_column(String(64), unique=True, nullable=False, index=True)
    bucket_type: Mapped[str] = mapped_column(String(32), default="public-read")
    quota_gb: Mapped[int] = mapped_column(Integer, default=10)
    access_key_id: Mapped[str] = mapped_column(String(64), nullable=False)
    secret_access_key: Mapped[str] = mapped_column(String(128), nullable=False)
    status: Mapped[str] = mapped_column(String(32), default="active", index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    user: Mapped[User] = relationship("User", back_populates="buckets")
