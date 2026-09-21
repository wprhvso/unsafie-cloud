from pydantic import BaseModel


class VmResult(BaseModel):
    id: str | None = None
    name: str
    vcpus: int
    ram_mb: int
    disk_gb: int
    image: str | None = None
    iso: str | None = None
    ip_address: str | None = None
    status: str = "pending"
    changed: bool = False


class IsoResult(BaseModel):
    id: str | None = None
    name: str
    is_shared: bool = False
    source_url: str | None = None
    status: str = "ready"
    changed: bool = False


class ImageResult(BaseModel):
    id: str | None = None
    name: str
    size_mb: int = 0
    status: str = "ready"


class PortResult(BaseModel):
    id: str | None = None
    node: str
    protocol: str = "tcp"
    host_port: int
    target_vm: str
    target_port: int
    status: str = "active"
    changed: bool = False


class DomainResult(BaseModel):
    id: str | None = None
    fqdn: str
    target_vm: str
    target_port: int = 80
    status: str = "active"
    changed: bool = False


class TokenResult(BaseModel):
    id: str | None = None
    name: str
    owner: str
    key_prefix: str
    secret_key: str | None = None
    changed: bool = False


class GrantResult(BaseModel):
    status: str
    owner: str
    granted_resource: str
    changed: bool = False


class QuotaResult(BaseModel):
    owner: str
    max_vcpus: int
    max_ram_mb: int
    max_disk_gb: int
    max_vms: int
    changed: bool = False


class NodeResult(BaseModel):
    name: str
    ip_address: str
    is_active: bool = True
    active_vms: int = 0
    changed: bool = False


class KernelResult(BaseModel):
    current_version: str
    active_slot: str
    status: str = "healthy"
    changed: bool = False


class BackupResult(BaseModel):
    name: str
    url: str
    created_at: str
    status: str = "completed"


class TaskEvent(BaseModel):
    task_name: str
    status: str
    duration: float = 0.0
    output: str | None = None
