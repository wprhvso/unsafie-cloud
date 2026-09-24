CREATE TABLE IF NOT EXISTS cluster_logs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    ts INTEGER NOT NULL,
    timestamp_iso TEXT NOT NULL,
    node_name TEXT NOT NULL,
    node_role TEXT NOT NULL DEFAULT 'node',
    cluster_id TEXT DEFAULT 'default',
    session_id TEXT,
    connection_id TEXT,
    trace_id TEXT,
    level TEXT NOT NULL DEFAULT 'INFO',
    subsystem TEXT NOT NULL,
    event_type TEXT NOT NULL,
    direction TEXT,
    src_ip TEXT,
    src_port INTEGER,
    dst_ip TEXT,
    dst_port INTEGER,
    protocol TEXT,
    domain TEXT,
    qtype TEXT,
    rcode TEXT,
    resolved_ips TEXT,
    route_action TEXT,
    route_reason TEXT,
    packet_size_bytes INTEGER,
    bytes_sent INTEGER DEFAULT 0,
    bytes_received INTEGER DEFAULT 0,
    duration_ms REAL,
    cipher_suite TEXT,
    alpn TEXT,
    tls_fingerprint TEXT,
    client_platform TEXT,
    client_version TEXT,
    interface_name TEXT,
    uplink_gateway TEXT,
    message TEXT NOT NULL,
    error_code TEXT,
    error_details TEXT,
    metadata_json TEXT DEFAULT '{}'
);

CREATE INDEX IF NOT EXISTS idx_cluster_logs_ts ON cluster_logs(ts DESC);
CREATE INDEX IF NOT EXISTS idx_cluster_logs_node ON cluster_logs(node_name, ts DESC);
CREATE INDEX IF NOT EXISTS idx_cluster_logs_subsystem_event ON cluster_logs(subsystem, event_type, ts DESC);
CREATE INDEX IF NOT EXISTS idx_cluster_logs_level ON cluster_logs(level);
CREATE INDEX IF NOT EXISTS idx_cluster_logs_route_action ON cluster_logs(route_action, ts DESC);
CREATE INDEX IF NOT EXISTS idx_cluster_logs_domain ON cluster_logs(domain);
CREATE INDEX IF NOT EXISTS idx_cluster_logs_src_dst ON cluster_logs(src_ip, dst_ip);
