# Unsafie Cloud (`wprhvso/unsafie-cloud`)

High-performance, zero-quorum Private Cloud IaaS Kernel and Edge Gateway written in Zig 0.15.

## Architecture

- **Autonomous Compute Nodes:** 3 independent bare-metal servers (`node1`, `node2`, `node3`) with zero-quorum shared-nothing architecture.
- **GitOps-Mesh State Store:** State is stored as structured JSON manifests in a local peer-to-peer Git repository replicated across all nodes without external database servers.
- **Embedded Ansible Engine:** Self-contained executable with embedded Ansible playbooks (`@embedFile`) for automated viral node bootstrapping and task execution.
- **Pure Zig Core (`zig/`):** Omnivorous multi-protocol edge server supporting HTTP/3 over QUIC (UDP 443), HTTP/2 & HTTP/1.1 (TCP 443), and pure WebSocket RPC without external web servers.
- **Incus KVM Hypervisor:** Hardware virtualization controlled directly via `/var/lib/incus/unix.socket` with ISO-first boot and QCOW2 image baking to Cloudflare R2.
- **Native Cloudflare R2 Management:** Zig kernel directly manages Cloudflare R2 buckets, lifecycle rules, image caching, and disaster recovery backups without external Terraform.
- **Routing & Networking:** L7 custom domain reverse-proxying with dynamic SNI SSL and L4 TCP/UDP port forwarding governed by explicit administrator grants.
- **Host Foundation:** Amnezia WireGuard (`awg0`) overlay mesh with automated host configuration via Ansible.

## Quick Start

1. Install prerequisites: `zig 0.15+`, `just`, `ansible`.
2. Build optimized release binary:
```shell
just build
```
3. Run local server:
```shell
just run
```
4. Deploy host infrastructure:
```shell
just host-setup
```
