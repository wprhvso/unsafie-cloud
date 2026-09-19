# Private Cloud Infrastructure (`wprhvso/unsafie-cloud`)

`wprhvso/unsafie-cloud` is an enterprise Private Cloud and Internal Developer Platform providing automated compute, container orchestration, managed databases, and object storage across a dedicated bare-metal mesh cluster.

## Key Features

- **Compute & Virtualization:** Self-service KVM virtual machines with cloud-init and automated resource allocation.
- **Container Orchestration:** High-availability K3s cluster with multi-tenant namespaces, vclusters, Envoy Gateway, and automated Cert-Manager TLS.
- **Managed Database Hub:** 11 native systemd database engines (PostgreSQL 17 with pgvector, ClickHouse, MongoDB, Valkey, Redpanda, RabbitMQ, Qdrant, Meilisearch, NATS JetStream, PocketBase, Garage S3).
- **Automated S3 Backups & Disaster Recovery:** Continuous WAL/oplog streaming, snapshot automation, and push-button restore procedures to Cloudflare R2 for all database systems.
- **Encrypted Mesh Networking:** Full-mesh overlay network powered by Amnezia WireGuard (`awg0`) with edge routing via Cloudflare DNS.
- **Centralized Observability:** Unified telemetry pipeline with VictoriaMetrics, VictoriaLogs, node_exporter textfile collectors, and Grafana dashboards.
- **Self-Service Developer Portal:** FastAPI control plane backend and Vue 3 web console with per-user quota management and unified API keys.

## Quick Start

1. Install prerequisites: `uv`, `just`, `ansible`, `terraform`.
2. Sync workspace dependencies:
```shell
just sync
```
3. Run linting and test suite:
```shell
just lint
just test
```
