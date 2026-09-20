const std = @import("std");

pub const BlindRelay = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) BlindRelay {
        return .{ .allocator = allocator };
    }

    pub fn forward(self: *BlindRelay, target_node_id: u16, payload: []const u8, out_stream: anytype) !usize {
        _ = self;
        var header: [3]u8 = undefined;
        header[0] = 0x02;
        header[1] = @intCast((target_node_id >> 8) & 0xff);
        header[2] = @intCast(target_node_id & 0xff);
        try out_stream.writeAll(&header);
        try out_stream.writeAll(payload);
        return header.len + payload.len;
    }
};
