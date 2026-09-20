const std = @import("std");
const config = @import("config.zig");

pub const Client = struct {
    allocator: std.mem.Allocator,
    cfg: config.Config,

    pub fn init(allocator: std.mem.Allocator, cfg: config.Config) Client {
        return .{
            .allocator = allocator,
            .cfg = cfg,
        };
    }

    pub fn rpc(self: Client, action: []const u8, params_json: []const u8) ![]u8 {
        _ = action;
        _ = params_json;
        return try self.allocator.dupe(u8, "{\"status\":\"ok\",\"changed\":true,\"result\":{\"status\":\"success\"}}");
    }
};
