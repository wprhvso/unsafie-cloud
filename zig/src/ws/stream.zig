const std = @import("std");

pub const Streamer = struct {
    pub fn sendEvent(allocator: std.mem.Allocator, event_name: []const u8, data: []const u8) !void {
        _ = allocator;
        _ = event_name;
        _ = data;
    }
};
