const std = @import("std");

pub const Config = struct {
    endpoint: []const u8,
    api_key: []const u8,

    pub fn load(allocator: std.mem.Allocator) !Config {
        var env_map = try std.process.getEnvMap(allocator);
        defer env_map.deinit();

        const ep = env_map.get("UNSAFIE_ENDPOINT") orelse "https://127.0.0.1:443";
        const key = env_map.get("UNSAFIE_API_KEY") orelse env_map.get("UNSAFIE_ADMIN_TOKEN") orelse "";

        return .{
            .endpoint = try allocator.dupe(u8, ep),
            .api_key = try allocator.dupe(u8, key),
        };
    }

    pub fn deinit(self: *Config, allocator: std.mem.Allocator) void {
        allocator.free(self.endpoint);
        allocator.free(self.api_key);
    }
};
