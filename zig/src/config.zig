const std = @import("std");

pub const baked_bootstrap_peers = [_][]const u8{
    "node1.unsafie.com:443",
};

pub const Config = struct {
    admin_token: []const u8,
    state_dir: []const u8,
    storage_dir: []const u8,
    r2_endpoint: []const u8,
    r2_bucket: []const u8,
    http_port: u16,
    https_port: u16,
    rpc_port: u16,
    vpn_iface: []const u8,
    vpn_subnet: []const u8,
    internal_domain: []const u8,
    bootstrap_peers: []const []const u8,

    pub fn load(allocator: std.mem.Allocator) !Config {
        var env_map = try std.process.getEnvMap(allocator);
        defer env_map.deinit();

        const admin_token = try allocator.dupe(u8, env_map.get("UNSAFIE_ADMIN_TOKEN") orelse "default_admin_token");

        var state_buf: [256]u8 = undefined;
        const state_dir_raw = blk: {
            if (env_map.get("STATE_DIR")) |s| break :blk s;
            if (std.fs.cwd().makePath("/var/lib/unsafie/state")) |_| {
                break :blk "/var/lib/unsafie/state";
            } else |_| {}
            if (std.posix.getenv("HOME")) |home| {
                const user_path = std.fmt.bufPrint(&state_buf, "{s}/.local/share/unsafie/state", .{home}) catch "/tmp/unsafie/state";
                if (std.fs.cwd().makePath(user_path)) |_| {
                    break :blk user_path;
                } else |_| {}
            }
            std.fs.cwd().makePath("/tmp/unsafie/state") catch {};
            break :blk "/tmp/unsafie/state";
        };
        const state_dir = try allocator.dupe(u8, state_dir_raw);

        var storage_buf: [256]u8 = undefined;
        const storage_dir_raw = blk: {
            if (env_map.get("STORAGE_DIR")) |s| break :blk s;
            if (std.fs.cwd().makePath("/var/lib/unsafie/storage")) |_| {
                break :blk "/var/lib/unsafie/storage";
            } else |_| {}
            if (std.posix.getenv("HOME")) |home| {
                const user_path = std.fmt.bufPrint(&storage_buf, "{s}/.local/share/unsafie/storage", .{home}) catch "/tmp/unsafie/storage";
                if (std.fs.cwd().makePath(user_path)) |_| {
                    break :blk user_path;
                } else |_| {}
            }
            std.fs.cwd().makePath("/tmp/unsafie/storage") catch {};
            break :blk "/tmp/unsafie/storage";
        };
        const storage_dir = try allocator.dupe(u8, storage_dir_raw);

        const r2_endpoint = try allocator.dupe(u8, env_map.get("R2_ENDPOINT") orelse "https://r2.cloudflarestorage.com");
        const r2_bucket = try allocator.dupe(u8, env_map.get("R2_BUCKET") orelse "infra-r2-backups");

        const http_port_str = env_map.get("HTTP_PORT") orelse "80";
        const https_port_str = env_map.get("HTTPS_PORT") orelse "443";
        const rpc_port_str = env_map.get("RPC_PORT") orelse "443";

        const http_port = std.fmt.parseInt(u16, http_port_str, 10) catch 80;
        const https_port = std.fmt.parseInt(u16, https_port_str, 10) catch 443;
        const rpc_port = std.fmt.parseInt(u16, rpc_port_str, 10) catch 443;

        const vpn_iface = try allocator.dupe(u8, env_map.get("VPN_IFACE") orelse "unsafie0");
        const vpn_subnet = try allocator.dupe(u8, env_map.get("VPN_SUBNET") orelse "10.42.0.0/16");
        const internal_domain = try allocator.dupe(u8, env_map.get("INTERNAL_DOMAIN") orelse "internal");

        var peers = try allocator.alloc([]const u8, baked_bootstrap_peers.len);
        for (baked_bootstrap_peers, 0..) |peer, i| {
            peers[i] = try allocator.dupe(u8, peer);
        }

        return .{
            .admin_token = admin_token,
            .state_dir = state_dir,
            .storage_dir = storage_dir,
            .r2_endpoint = r2_endpoint,
            .r2_bucket = r2_bucket,
            .http_port = http_port,
            .https_port = https_port,
            .rpc_port = rpc_port,
            .vpn_iface = vpn_iface,
            .vpn_subnet = vpn_subnet,
            .internal_domain = internal_domain,
            .bootstrap_peers = peers,
        };
    }

    pub fn deinit(self: *Config, allocator: std.mem.Allocator) void {
        allocator.free(self.admin_token);
        allocator.free(self.state_dir);
        allocator.free(self.storage_dir);
        allocator.free(self.r2_endpoint);
        allocator.free(self.r2_bucket);
        allocator.free(self.vpn_iface);
        allocator.free(self.vpn_subnet);
        allocator.free(self.internal_domain);
        for (self.bootstrap_peers) |peer| {
            allocator.free(peer);
        }
        allocator.free(self.bootstrap_peers);
    }
};
