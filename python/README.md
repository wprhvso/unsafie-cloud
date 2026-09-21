# Unsafie Cloud Python SDK (`unsafie-cloud`)

Official asynchronous, pure WebSocket and HTTP RPC Python SDK for Unsafie Cloud IaaS Kernel.

## Installation

```shell
pip install unsafie-cloud
```

## Full Workflow & Bootstrap Examples

### 1. Complete Cluster Bootstrap from Python (Viral Self-Replication)

An administrator can bootstrap new nodes across the cluster directly from Python code:

```python
import asyncio
from unsafie_cloud import Client


async def bootstrap_cluster():
    # 1. Connect to initial seed node using admin master token
    async with Client(
        endpoint="https://node1.api.domain.com", api_key="ADMIN_MASTER_TOKEN"
    ) as admin:
        # 2. Add Node 2 over SSH (automatically installs Ansible, WireGuard, KVM, and replicates state)
        node2 = await admin.node.add(
            host="95.0.0.2", ssh_user="root", ssh_key="/root/.ssh/id_ed25519"
        )
        print(f"Node 2 bootstrapped and joined mesh: {node2.ip_address}")

        # 3. Add Node 3 (e.g. office server behind NAT)
        node3 = await admin.node.add(
            host="192.168.1.100", ssh_user="root", ssh_key="/root/.ssh/id_ed25519"
        )
        print(f"Node 3 bootstrapped and joined mesh: {node3.ip_address}")

        # 4. Mint API token for developer Vladimir
        token = await admin.token.ensure(
            name="vladimir-cli",
            owner="vladimir",
            scopes=["vm.manage", "image.bake", "domain.manage"],
        )
        print(f"Minted token for Vladimir: {token.secret_key}")

        # 5. Grant explicit quota and port/domain whitelist permissions
        await admin.quota.ensure(
            owner="vladimir", max_vcpus=32, max_ram_mb=65536, max_disk_gb=1000, max_vms=10
        )
        await admin.grant.domain(owner="vladimir", fqdn="myshop.com")
        await admin.grant.port(owner="vladimir", node="node1", protocol="tcp", host_port=25565)

        # 6. Upload Shared ISO available to all users by name
        await admin.iso.ensure(
            name="alpine-3.20",
            url="https://dl-cdn.alpinelinux.org/alpine/v3.20/releases/x86_64/alpine-virt-3.20.3-x86_64.iso",
            is_shared=True,
        )
        print("Alpine 3.20 registered as shared ISO!")


asyncio.run(bootstrap_cluster())
```

---

### 2. User Workflow (Provision, Tasks, Bake, Domain, Ports)

A developer uses their personal API token to manage compute, storage, and networking:

```python
import asyncio
from unsafie_cloud import Client


async def developer_workflow():
    async with Client(
        endpoint="https://node1.api.domain.com", api_key="phx_live_vladimir_..."
    ) as cloud:
        # 1. Idempotently ensure VM with Ansible tasks
        vm = await cloud.vm.ensure(
            name="worker-01",
            vcpus=4,
            ram_mb=8192,
            disk_gb=50,
            iso="alpine-3.20",
            tasks=[
                {"name": "Update repositories", "apt": {"update_cache": True}},
                {"name": "Install docker", "apt": {"name": ["docker.io"], "state": "present"}},
            ],
        )
        print(f"VM ready: {vm.name} at {vm.ip_address} (Changed: {vm.changed})")

        # 2. Bake golden QCOW2 image from VM output
        image = await cloud.vm.bake(name="worker-01", image_name="alpine-docker-v1")
        print(f"Image baked and cached in R2: {image.name}")

        # 3. Spawn fleet on baked image (sub-second launch)
        for i in range(1, 4):
            await cloud.vm.ensure(
                name=f"prod-app-{i}", image="alpine-docker-v1", vcpus=4, ram_mb=8192
            )

        # 4. Attach custom domain with manual PEM SSL
        domain = await cloud.domain.ensure(
            fqdn="myshop.com",
            target_vm="prod-app-1",
            target_port=80,
            ssl_cert=open("certs/fullchain.pem").read(),
            ssl_key=open("certs/privkey.pem").read(),
        )
        print(f"Domain mapped: https://{domain.fqdn}")

        # 5. Open L4 TCP port forward
        port = await cloud.port.ensure(
            node="node1", protocol="tcp", host_port=25565, target_vm="prod-app-1", target_port=25565
        )
        print(f"Port forwarded: node1:25565 -> prod-app-1:25565")


asyncio.run(developer_workflow())
```

---

### 3. Zero-Downtime Kernel Upgrade from Python

```python
async def upgrade_kernel():
    async with Client(
        endpoint="https://node1.api.domain.com", api_key="ADMIN_MASTER_TOKEN"
    ) as admin:
        result = await admin.kernel.upgrade(
            version="0.2.0",
            sha256="b4e81fa9c0...",
            download_url="r2://binaries/unsafie-cloud-0.2.0",
        )
        print(f"Kernel upgrade status: {result.status} on {result.active_slot}")


asyncio.run(upgrade_kernel())
```
