from __future__ import annotations

from datetime import datetime

from sqlalchemy import BigInteger, Boolean, DateTime, ForeignKey, Integer, String, Text, func
from sqlalchemy.dialects.postgresql import ARRAY
from sqlalchemy.orm import Mapped, mapped_column, relationship

from infra_db.base import Base


class Plan(Base):
    __tablename__ = "plans"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    name: Mapped[str] = mapped_column(String(64), unique=True, nullable=False)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    max_vcpus: Mapped[int] = mapped_column(Integer, default=2)
    max_ram_mb: Mapped[int] = mapped_column(Integer, default=4096)
    max_disk_gb: Mapped[int] = mapped_column(Integer, default=30)
    max_vms: Mapped[int] = mapped_column(Integer, default=1)
    max_tenants: Mapped[int] = mapped_column(Integer, default=1)
    max_domains: Mapped[int] = mapped_column(Integer, default=3)
    max_kameleo_slots: Mapped[int] = mapped_column(Integer, default=1)
    allowed_k8s_kinds: Mapped[list[str]] = mapped_column(ARRAY(String(32)), default=["ns"])
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    users: Mapped[list[User]] = relationship("User", back_populates="plan")


class User(Base):
    __tablename__ = "users"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    github_id: Mapped[int] = mapped_column(BigInteger, unique=True, nullable=False, index=True)
    github_login: Mapped[str] = mapped_column(String(255), nullable=False)
    name: Mapped[str | None] = mapped_column(String(255), nullable=True)
    email: Mapped[str] = mapped_column(String(255), nullable=False, index=True)
    avatar_url: Mapped[str | None] = mapped_column(Text, nullable=True)
    role: Mapped[str] = mapped_column(String(32), default="student")
    plan_id: Mapped[int | None] = mapped_column(Integer, ForeignKey("plans.id"), nullable=True)
    custom_ram_override_mb: Mapped[int | None] = mapped_column(Integer, nullable=True)
    ssh_public_keys: Mapped[list[str]] = mapped_column(ARRAY(Text), default=[])
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    plan: Mapped[Plan | None] = relationship("Plan", back_populates="users")
    tenants: Mapped[list[Tenant]] = relationship(
        "Tenant", back_populates="user", cascade="all, delete-orphan"
    )
    vms: Mapped[list[KvmVm]] = relationship(
        "KvmVm", back_populates="user", cascade="all, delete-orphan"
    )
    databases: Mapped[list[DatabaseInstance]] = relationship(
        "DatabaseInstance", back_populates="user", cascade="all, delete-orphan"
    )
    buckets: Mapped[list[S3Bucket]] = relationship(
        "S3Bucket", back_populates="user", cascade="all, delete-orphan"
    )
    domains: Mapped[list[DomainRecord]] = relationship(
        "DomainRecord", back_populates="user", cascade="all, delete-orphan"
    )
    api_keys: Mapped[list[ApiKey]] = relationship(
        "ApiKey", back_populates="user", cascade="all, delete-orphan"
    )
    kameleo_leases: Mapped[list[KameleoLease]] = relationship(
        "KameleoLease", back_populates="user", cascade="all, delete-orphan"
    )
