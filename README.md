# Unsafie Cloud (wprhvso/unsafie-cloud)

High-performance, pure in-memory Mesh VPN and Sovereign Private Cloud Kernel powered by AmneziaWG in Zig 0.15.

## Architecture Highlights

- **Pure In-Memory State (RAM):** Completely eliminates SQLite, PostgreSQL, disk ledgers, and databases. All routes, peer sessions, DNS caches, and telemetry live exclusively in memory.
- **Single Sacred Configuration (`unsafie.yaml`):** The entire system state—including identities, secret keys, AmneziaWG obfuscation headers, peer topologies, RBAC roles, and smart routing rules—is declared in a single transparent XAML file.
- **Minimalist Execution:** The standalone binary takes only one optional argument: the path to `unsafie.yaml`.
  ` located right next to the binary if omitted.
- **Pure AmneziaWG Transport:** Direct UDP-based WireGuard tunnel with advanced obfuscation parameters (Jc, Jmin, Jmax, S1, S2, H1, H2, H3, H4, psk) to resist DPI heuristics without HTTP masquerades, fake TLS handshakes, or SNI manipulation.
- **Smart Routing & Dynamic DNS-Learner:** In-memory rule engine evaluating destination CIDRs and domains. Domestic traffic (e.g. Russian domains and services) routes directly with cached IPs in RAM (LearnerSet), while foreign traffic routes through the mesh tunnel.
- **Timestamped Mesh Synchronization:** When an authorized peer (can_sync_config or admin role) broadcasts a configuration with a newer timestamp, all mesh nodes adopt it into memory and persist it locally.
- **Compile-Time Android Embedding:** Zero client-side configuration file baking for servers and desktops, but compile-time embedded YAML (@embedFile) for native Android VpnService builds.

## Quick Start

### Build Standalone Binary

cd zig && zig build -Doptimize=ReleaseFast

### Run Node

./zig/zig-out/bin/unsafie
