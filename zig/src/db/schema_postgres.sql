CREATE TABLE IF NOT EXISTS cluster_logs (
    id BIGSERIAL PRIMARY KEY,
    ts BIGINT NOT NULL,
    timestamp_iso TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    node_name VARCHAR(64) NOT NULL,
    node_role VARCHAR(32) NOT NULL DEFAULT 'node',
    cluster_id VARCHAR(64) DEFAULT 'default',
    session_id VARCHAR(64),
    connection_id VARCHAR(64),
    trace_id VARCHAR(64),
    level VARCHAR(16) NOT NULL DEFAULT 'INFO',
    subsystem VARCHAR(32) NOT NULL,
    event_type VARCHAR(64) NOT NULL,
    direction VARCHAR(16),
    src_ip VARCHAR(45),
    src_port INTEGER,
    dst_ip VARCHAR(45),
    dst_port INTEGER,
    protocol VARCHAR(16),
    domain VARCHAR(255),
    qtype VARCHAR(16),
    rcode VARCHAR(16),
    resolved_ips TEXT,
    route_action VARCHAR(32),
    route_reason TEXT,
    packet_size_bytes INTEGER,
    bytes_sent BIGINT DEFAULT 0,
    bytes_received BIGINT DEFAULT 0,
    duration_ms NUMERIC(10, 3),
    cipher_suite VARCHAR(64),
    alpn VARCHAR(32),
    tls_fingerprint VARCHAR(128),
    client_platform VARCHAR(32),
    client_version VARCHAR(32),
    interface_name VARCHAR(32),
    uplink_gateway VARCHAR(45),
    message TEXT NOT NULL,
    error_code VARCHAR(64),
    error_details TEXT,
    metadata_json JSONB DEFAULT '{}'::jsonb
);

CREATE INDEX IF NOT EXISTS idx_cluster_logs_ts ON cluster_logs(ts DESC);
CREATE INDEX IF NOT EXISTS idx_cluster_logs_node ON cluster_logs(node_name, ts DESC);
CREATE INDEX IF NOT EXISTS idx_cluster_logs_subsystem_event ON cluster_logs(subsystem, event_type, ts DESC);
CREATE INDEX IF NOT EXISTS idx_cluster_logs_level ON cluster_logs(level);
CREATE INDEX IF NOT EXISTS idx_cluster_logs_route_action ON cluster_logs(route_action, ts DESC);
CREATE INDEX IF NOT EXISTS idx_cluster_logs_domain ON cluster_logs(domain);
CREATE INDEX IF NOT EXISTS idx_cluster_logs_src_dst ON cluster_logs(src_ip, dst_ip);
CREATE INDEX IF NOT EXISTS idx_cluster_logs_metadata ON cluster_logs USING GIN(metadata_json);
