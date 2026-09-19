const std = @import("std");
const cache = @import("cache.zig");

pub const Baker = struct {
    pub fn freezeAndConvert(allocator: std.mem.Allocator, vm_name: []const u8, output_path: []const u8) !void {
        _ = allocator;
        _ = vm_name;
        _ = output_path;
    }

    pub fn bakeAndCache(allocator: std.mem.Allocator, vm_name: []const u8, image_name: []const u8, qcow_cache: cache.QcowCache) !void {
        const tmp_path = try std.fmt.allocPrint(allocator, "/tmp/{s}.qcow2", .{image_name});
        defer allocator.free(tmp_path);

        try freezeAndConvert(allocator, vm_name, tmp_path);
        try qcow_cache.putCachedImage(image_name, tmp_path);
    }
};
