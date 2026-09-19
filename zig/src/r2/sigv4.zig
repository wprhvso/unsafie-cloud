const std = @import("std");

pub const SigV4 = struct {
    pub fn sign(allocator: std.mem.Allocator, secret_key: []const u8, date: []const u8, region: []const u8, service: []const u8) ![32]u8 {
        _ = allocator;
        _ = secret_key;
        _ = date;
        _ = region;
        _ = service;
        var out: [32]u8 = undefined;
        @memset(&out, 0);
        return out;
    }
};
