CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    login VARCHAR(255) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    role VARCHAR(32) DEFAULT 'user',
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS quotas (
    id SERIAL PRIMARY KEY,
    user_id INTEGER UNIQUE REFERENCES users(id) ON DELETE CASCADE,
    max_vcpus INTEGER DEFAULT 4,
    max_ram_mb INTEGER DEFAULT 8192,
    max_disk_gb INTEGER DEFAULT 50,
    max_vms INTEGER DEFAULT 2
);

CREATE TABLE IF NOT EXISTS api_keys (
    id UUID PRIMARY KEY,
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    name VARCHAR(128) NOT NULL,
    key_prefix VARCHAR(16) NOT NULL,
    key_hash VARCHAR(255) UNIQUE NOT NULL,
    scopes TEXT[] DEFAULT ARRAY['*'],
    is_revoked BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS vms (
    id UUID PRIMARY KEY,
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    name VARCHAR(64) NOT NULL,
    node VARCHAR(32) NOT NULL,
    image VARCHAR(64),
    iso VARCHAR(64),
    vcpus INTEGER DEFAULT 2,
    ram_mb INTEGER DEFAULT 4096,
    disk_gb INTEGER DEFAULT 30,
    ip_address VARCHAR(45),
    status VARCHAR(32) DEFAULT 'pending',
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_user_vm_name UNIQUE (user_id, name)
);

CREATE TABLE IF NOT EXISTS isos (
    id UUID PRIMARY KEY,
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    name VARCHAR(64) NOT NULL,
    is_shared BOOLEAN DEFAULT FALSE,
    source_url TEXT,
    r2_storage_key VARCHAR(255) NOT NULL,
    size_bytes BIGINT DEFAULT 0,
    status VARCHAR(32) DEFAULT 'ready',
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_user_iso_name UNIQUE (user_id, name)
);

CREATE TABLE IF NOT EXISTS images (
    id UUID PRIMARY KEY,
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    name VARCHAR(64) NOT NULL,
    r2_storage_key VARCHAR(255) NOT NULL,
    size_mb INTEGER DEFAULT 0,
    status VARCHAR(32) DEFAULT 'ready',
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_user_image_name UNIQUE (user_id, name)
);

CREATE TABLE IF NOT EXISTS domain_grants (
    id UUID PRIMARY KEY,
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    fqdn VARCHAR(255) UNIQUE NOT NULL,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS port_grants (
    id UUID PRIMARY KEY,
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    node VARCHAR(32) NOT NULL,
    protocol VARCHAR(8) DEFAULT 'tcp',
    host_port INTEGER NOT NULL,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_port_grant UNIQUE (node, protocol, host_port)
);

CREATE TABLE IF NOT EXISTS domains (
    id UUID PRIMARY KEY,
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    fqdn VARCHAR(255) UNIQUE NOT NULL,
    target_vm_id UUID REFERENCES vms(id) ON DELETE CASCADE,
    target_port INTEGER DEFAULT 80,
    ssl_cert_pem TEXT,
    ssl_key_pem TEXT,
    status VARCHAR(32) DEFAULT 'active',
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS ports (
    id UUID PRIMARY KEY,
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    node VARCHAR(32) NOT NULL,
    protocol VARCHAR(8) DEFAULT 'tcp',
    host_port INTEGER NOT NULL,
    target_vm_id UUID REFERENCES vms(id) ON DELETE CASCADE,
    target_port INTEGER NOT NULL,
    status VARCHAR(32) DEFAULT 'active',
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_node_port UNIQUE (node, protocol, host_port)
);
