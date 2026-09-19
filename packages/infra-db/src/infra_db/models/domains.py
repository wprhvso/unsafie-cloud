from __future__ import annotations

from datetime import datetime
from uuid import UUID, uuid4

from sqlalchemy import Boolean, DateTime, ForeignKey, Integer, String, Text, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from infra_db.base import Base


class DomainRecord(Base):
    __tablename__ = "domains"

    id: Mapped[UUID] = mapped_column(primary_key=True, default=uuid4)
    user_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    fqdn: Mapped[str] = mapped_column(String(255), unique=True, nullable=False, index=True)
    is_custom: Mapped[bool] = mapped_column(Boolean, default=False)
    cloudflare_record_id: Mapped[str | None] = mapped_column(String(64), nullable=True)
    target_type: Mapped[str] = mapped_column(String(32), nullable=False)
    target_id: Mapped[UUID | None] = mapped_column(nullable=True)
    status: Mapped[str] = mapped_column(String(32), default="active", index=True)
    moderation_comment: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    user: Mapped[User] = relationship("User", back_populates="domains")
