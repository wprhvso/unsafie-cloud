from decimal import Decimal
from uuid import UUID

from pydantic import BaseModel, Field


class TenantCreate(BaseModel):
    name: str = Field(min_length=3, max_length=63, pattern="^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$")
    kind: str = Field(default="ns", pattern="^(ns|vc)$")
    cpu_limit_cores: Decimal = Field(default=Decimal("2.00"), ge=Decimal("0.5"), le=Decimal("8.0"))
    ram_limit_mb: int = Field(default=4096, ge=512, le=16384)
    storage_limit_gb: int = Field(default=20, ge=5, le=100)
    subdomain: str | None = None
    wildcard: bool = False


class TenantResponse(BaseModel):
    id: UUID
    name: str
    kind: str
    cpu_limit_cores: Decimal
    ram_limit_mb: int
    storage_limit_gb: int
    domains: list[str]
    status: str
