const std = @import("std");

pub const Config = struct {
    admin_token: []const u8,
    database_url: []const u8,
    http_port: u16,
    https_port: u16,
    rpc_port: u16,

    pub fn load(allocator: std.mem.Allocator) !Config {
        var env_map = try std.process.getEnvMap(allocator);
        defer env_map.deinit();

        const admin_token = try allocator.dupe(u8, env_map.get("UNSAFIE_ADMIN_TOKEN") orelse "default_admin_token");
        const database_url = try allocator.dupe(u8, env_map.get("DATABASE_URL") orelse "postgresql://postgres:postgres@127.0.0.1:5432/unsafie_cloud");

        const http_port_str = env_map.get("HTTP_PORT") orelse "80";
        const https_port_str = env_map.get("HTTPS_PORT") orelse "443";
        const rpc_port_str = env_map.get("RPC_PORT") orelse "8000";

        const http_port = std.fmt.parseInt(u16, http_port_str, 10) catch 80;
        const https_port = std.fmt.parseInt(u16, https_port_str, 10) catch 443;
        const rpc_port = std.fmt.parseInt(u16, rpc_port_str, 10) catch 8000;

        return .{
            .admin_token = admin_token,
            .database_url = database_url,
            .http_port = http_port,
            .https_port = https_port,
            .rpc_port = rpc_port,
        };
    }

    pub fn deinit(self: *Config, allocator: std.mem.Allocator) void {
        allocator.free(self.admin_token);
        allocator.free(self.database_url);
    }
};
