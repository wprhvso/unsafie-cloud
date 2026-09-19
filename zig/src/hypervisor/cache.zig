const std = @import("std");

pub const QcowCache = struct {
    garage_endpoint: []const u8,
    bucket: []const u8,

    pub fn init(garage_endpoint: []const u8, bucket: []const u8) QcowCache {
        return .{
            .garage_endpoint = garage_endpoint,
            .bucket = bucket,
        };
    }

    pub fn getCachedImage(self: QcowCache, allocator: std.mem.Allocator, image_name: []const u8) !?[]const u8 {
        _ = self;
        _ = image_name;
        _ = allocator;
        return null;
    }

    pub fn putCachedImage(self: QcowCache, image_name: []const u8, local_qcow_path: []const u8) !void {
        _ = self;
        _ = image_name;
        _ = local_qcow_path;
    }
};
