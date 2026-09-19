const std = @import("std");

pub const TokenService = struct {
    pub fn generateToken(allocator: std.mem.Allocator) ![]const u8 {
        var random_bytes: [24]u8 = undefined;
        std.crypto.random.bytes(&random_bytes);
        var hex_buf: [48]u8 = undefined;
        _ = try std.fmt.bufPrint(&hex_buf, "{s}", .{std.fmt.fmtSliceHexLower(&random_bytes)});
        return try std.fmt.allocPrint(allocator, "phx_live_{s}", .{hex_buf});
    }
};
