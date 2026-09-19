from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, Field


class ApiKeyCreate(BaseModel):
    name: str = Field(min_length=1, max_length=128)
    scopes: list[str] = Field(default=["llm", "browser", "tasks"])


class ApiKeyResponse(BaseModel):
    id: UUID
    name: str
    key_prefix: str
    scopes: list[str]
    is_revoked: bool
    created_at: datetime


class ApiKeyCreated(ApiKeyResponse):
    secret_key: str
