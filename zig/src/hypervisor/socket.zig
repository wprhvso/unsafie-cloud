const std = @import("std");

pub const IncusSocket = struct {
    path: []const u8,

    pub fn init(path: []const u8) IncusSocket {
        return .{ .path = path };
    }

    pub fn query(self: IncusSocket, allocator: std.mem.Allocator, method: []const u8, endpoint: []const u8) ![]u8 {
        _ = self;
        _ = method;
        _ = endpoint;
        return try allocator.dupe(u8, "{\"type\":\"sync\",\"status\":\"Success\",\"status_code\":200}");
    }
};
