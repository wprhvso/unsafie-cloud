from uuid import UUID

from pydantic import BaseModel, Field


class DomainCreate(BaseModel):
    fqdn: str = Field(min_length=4, max_length=255)
    is_custom: bool = False
    target_type: str = Field(default="k3s_tenant")


class DomainResponse(BaseModel):
    id: UUID
    fqdn: str
    is_custom: bool
    target_type: str
    status: str
