# Unsafie Cloud (`wprhvso/unsafie-cloud`)

High-performance, zero-quorum Sovereign Private Cloud IaaS Kernel, Multi-Hop Mesh VPN, and Edge Gateway written in Zig 0.15.

## Installation

### Linux & macOS (One-line installer)

```shell
curl -fsSL https://raw.githubusercontent.com/wprhvso/unsafie-cloud/main/scripts/install.sh | bash
```

### Windows (PowerShell)

```powershell
irm https://raw.githubusercontent.com/wprhvso/unsafie-cloud/main/scripts/install.ps1 | iex
```

### Python SDK

```shell
pip install ./python
```

## Architecture

- **Sovereign Mesh Nodes:** Any device (bare-metal server, home PC, laptop, phone) is a sovereign peer with unified Zig 0.15 core.
- **Single Unified Binary (`unsafie`):** Server, CLI, node daemon, and VPN engine combined into one standalone binary.
- **Native Idempotent Host Provisioning:** Zig kernel directly manages Linux sysctl parameters (BBR/FQ), UFW firewall rules, SSH hardening, and systemd units without external Ansible or Python.
- **Native L3 Mesh VPN (`unsafie0`):** Full L3 packet tunneling without WireGuard or third-party kernel modules. Native Linux Multi-Queue TUN with `IFF_VNET_HDR` and Wintun Ring-0 driver on Windows.
- **Smart Routing & DumbVPN DNS-Learner:** Real IPs without Fake-IP breakage. Russian traffic routes directly via in-memory `LearnerSet` (TTL 30m) and `rules.bin`, foreign traffic routes via the lowest-cost peer.
- **Multi-Hop Relay Mesh:** Automated Dijkstra pathfinding over QUIC telemetry. Bypasses regional throttling by routing through intermediate domestic bridge nodes with zero-knowledge blind forwarding.
- **Unified Port 443:** Authentic web server serving HTTPS content while multiplexing MASQUE CONNECT-UDP (HTTP/3) and RFC 8441 WebSockets (HTTP/2) for authenticated VPN peers.
- **Split-DNS (`*.internal`):** Built-in DNS resolver on `10.42.0.1:53` mapping `node*.internal` and `vm-*.internal` instances.
- **Incus KVM Hypervisor:** Hardware virtualization controlled directly via `/var/lib/incus/unix.socket` with ISO-first boot and QCOW2 baking to Cloudflare R2.
- **Native Cloudflare R2 Management:** Zig kernel directly manages Cloudflare R2 buckets, lifecycle rules, image caching, and disaster recovery backups without external Terraform.
- **Everywhere GitOps:** Mandatory local Git store on every node (`state/git.zig`) with P2P replication over binary RPC streams.
- **Zero-Config Client Baking:** Pre-configured standalone binaries (`unsafie bake --target exe/apk`) with embedded profile overlays for one-click connectivity.
- **Dual-Slot A/B Auto-Upgrade:** Self-updating nodes with Ed25519 signature verification and zero-downtime socket handover.
- **Embedded SQLite & FTS5:** Integrated WAL-mode SQLite database with full-text search and Blake3 event ledger.
- **Version Tracking (`vuh`):** Monorepo module versions synchronized with version-update-helper (`.vuh`).

## Monorepo Layout

- `zig/`: Unified Sovereign Cloud Kernel & CLI (`unsafie`), L3 Mesh VPN, Edge Gateway, KVM Hypervisor, SQLite Storage, Host Provisioner.
- `python/`: Asynchronous Python client library (`unsafie_cloud`).
- `android/`: Native Android VpnService application wrapper.
- `scripts/`: Fast installation scripts for Linux, macOS, and Windows.

## Development & CI Commands

Format Zig sources:

```shell
just fix
```

Run local node / client:

```shell
just run
```

Run CI validation:

```shell
just ci-zig-format
just ci-zig-test
just ci-android-ktlint
just ci-android-lint
just ci-python-ruff
just ci-python-ruff-format
just ci-python-basedpyright
```

Build release artifacts and deploy to GitHub:

```shell
just cd-all
```
