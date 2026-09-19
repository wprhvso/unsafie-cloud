# Infrastructure Platform

Private Cloud and Internal Developer Platform for the organization.

## Architecture

- 3-Node HA Cluster across hybrid providers (Node 1, Node 2, Node 3)
- Encrypted overlay mesh network with Amnezia WireGuard
- Direct host database management under systemd via official APT packages
- High-availability K3s cluster with Envoy Gateway and Cert-Manager
- Fast developer portal with FastAPI backend and Vue 3 frontend
- Self-service KVM virtual machines, K3s tenants, databases and S3 storage
- Centralized observability with VictoriaMetrics, VictoriaLogs and Grafana

## Quick Start

1. Install prerequisites: uv, just, ansible, terraform.
2. Sync dependencies:
```shell
just sync
```
3. Run linting:
```shell
just lint
```
