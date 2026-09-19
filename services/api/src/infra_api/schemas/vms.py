from uuid import UUID

from pydantic import BaseModel, Field


class VmCreate(BaseModel):
    name: str = Field(min_length=3, max_length=63, pattern="^[a-z0-9-]{3,63}$")
    node: str = Field(default="node1-aeza")
    vcpus: int = Field(default=2, ge=1, le=8)
    ram_mb: int = Field(default=4096, ge=1024, le=16384)
    disk_gb: int = Field(default=30, ge=10, le=100)


class VmResponse(BaseModel):
    id: UUID
    name: str
    node: str
    vcpus: int
    ram_mb: int
    disk_gb: int
    ip_address: str | None = None
    status: str
