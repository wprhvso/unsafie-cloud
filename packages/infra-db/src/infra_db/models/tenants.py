from __future__ import annotations

from datetime import datetime
from decimal import Decimal
from uuid import UUID, uuid4

from sqlalchemy import DateTime, ForeignKey, Integer, Numeric, String, Text, func
from sqlalchemy.dialects.postgresql import ARRAY
from sqlalchemy.orm import Mapped, mapped_column, relationship

from infra_db.base import Base


class Tenant(Base):
    __tablename__ = "tenants"

    id: Mapped[UUID] = mapped_column(primary_key=True, default=uuid4)
    user_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    name: Mapped[str] = mapped_column(String(64), unique=True, nullable=False, index=True)
    kind: Mapped[str] = mapped_column(String(16), default="ns")
    cpu_limit_cores: Mapped[Decimal] = mapped_column(Numeric(4, 2), default=Decimal("2.00"))
    ram_limit_mb: Mapped[int] = mapped_column(Integer, default=4096)
    storage_limit_gb: Mapped[int] = mapped_column(Integer, default=20)
    domains: Mapped[list[str]] = mapped_column(ARRAY(String(255)), default=[])
    kubeconfig_encrypted: Mapped[str | None] = mapped_column(Text, nullable=True)
    status: Mapped[str] = mapped_column(String(32), default="provisioning", index=True)
    last_traffic_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    user: Mapped[User] = relationship("User", back_populates="tenants")


class KvmVm(Base):
    __tablename__ = "vms"

    id: Mapped[UUID] = mapped_column(primary_key=True, default=uuid4)
    user_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    name: Mapped[str] = mapped_column(String(64), unique=True, nullable=False, index=True)
    node: Mapped[str] = mapped_column(String(64), nullable=False)
    vcpus: Mapped[int] = mapped_column(Integer, default=2)
    ram_mb: Mapped[int] = mapped_column(Integer, default=4096)
    disk_gb: Mapped[int] = mapped_column(Integer, default=30)
    ip_address: Mapped[str | None] = mapped_column(String(45), nullable=True)
    pin_cores: Mapped[str | None] = mapped_column(String(32), nullable=True)
    status: Mapped[str] = mapped_column(String(32), default="running", index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    user: Mapped[User] = relationship("User", back_populates="vms")
