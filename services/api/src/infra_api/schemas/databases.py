from uuid import UUID

from pydantic import BaseModel, Field


class DatabaseCreate(BaseModel):
    db_type: str = Field(
        pattern="^(postgres|valkey|mongo|clickhouse|redpanda|rabbitmq|nats|meilisearch|qdrant|pocketbase)$"
    )
    db_name: str = Field(min_length=2, max_length=63, pattern="^[a-z0-9_]{2,63}$")


class DatabaseResponse(BaseModel):
    id: UUID
    db_type: str
    db_name: str
    db_user: str
    port: int
    connection_url: str | None = None
    status: str


class S3BucketCreate(BaseModel):
    bucket_name: str = Field(min_length=3, max_length=63, pattern="^[a-z0-9.-]{3,63}$")
    bucket_type: str = Field(default="public-read", pattern="^(private|public-read)$")
    quota_gb: int = Field(default=10, ge=1, le=50)


class S3BucketResponse(BaseModel):
    id: UUID
    bucket_name: str
    bucket_type: str
    quota_gb: int
    access_key_id: str
    status: str
