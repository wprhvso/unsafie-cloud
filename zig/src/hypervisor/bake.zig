const std = @import("std");

pub const Baker = struct {
    pub fn freezeAndConvert(allocator: std.mem.Allocator, vm_name: []const u8, output_path: []const u8) !void {
        _ = allocator;
        _ = vm_name;
        _ = output_path;
    }
};
