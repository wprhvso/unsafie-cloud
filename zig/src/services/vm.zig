const std = @import("std");

pub const VmService = struct {
    pub fn ensure(allocator: std.mem.Allocator, name: []const u8, vcpus: i32, ram_mb: i32) !void {
        _ = allocator;
        _ = name;
        _ = vcpus;
        _ = ram_mb;
    }
};
