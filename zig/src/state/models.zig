const std = @import("std");

pub const VmManifest = struct {
    name: []const u8,
    node: []const u8,
    vcpus: i32,
    ram_mb: i32,
    disk_gb: i32,
    image: ?[]const u8 = null,
    iso: ?[]const u8 = null,
    ip_address: ?[]const u8 = null,
    status: []const u8 = "pending",
};

pub const IsoManifest = struct {
    name: []const u8,
    is_shared: bool,
    source_url: ?[]const u8 = null,
    r2_key: []const u8,
    size_bytes: i64 = 0,
    status: []const u8 = "ready",
};

pub const DomainManifest = struct {
    fqdn: []const u8,
    target_vm: []const u8,
    target_port: u16 = 80,
    ssl_cert_pem: ?[]const u8 = null,
    ssl_key_pem: ?[]const u8 = null,
};

pub const PortManifest = struct {
    node: []const u8,
    protocol: []const u8 = "tcp",
    host_port: u16,
    target_vm: []const u8,
    target_port: u16,
};

pub const TokenManifest = struct {
    name: []const u8,
    owner: []const u8,
    key_prefix: []const u8,
    key_hash: []const u8,
    scopes: []const []const u8,
};

pub const GrantManifest = struct {
    owner: []const u8,
    grants: []const []const u8,
};

pub const KernelManifest = struct {
    version: []const u8,
    sha256: []const u8,
    download_url: []const u8,
    signature_ed25519: []const u8 = "",
    active_slot: []const u8 = "slot_a",
};

pub const NodeCapabilities = struct {
    gitops_store: bool = true,
    compute_kvm: bool = false,
    ingress_443: bool = false,
};

pub const NodeManifest = struct {
    name: []const u8,
    role: []const u8 = "workstation",
    ip_address: []const u8,
    internal_domain: []const u8,
    public_key: []const u8 = "",
    capabilities: NodeCapabilities = .{},
    listen_port: ?u16 = null,
    created_at: i64 = 0,
};

pub const RouteManifest = struct {
    prefix: []const u8,
    next_hop: []const u8,
    metric: u32 = 100,
};
