const std = @import("std");
const sigv4 = @import("sigv4.zig");

pub const R2Client = struct {
    endpoint: []const u8,
    bucket: []const u8,
    access_key: []const u8,
    secret_key: []const u8,

    pub fn ensureBucket(self: R2Client, bucket_name: []const u8) !void {
        _ = self;
        _ = bucket_name;
    }

    pub fn setBucketLifecycle(self: R2Client, bucket_name: []const u8, retention_days: u32) !void {
        _ = self;
        _ = bucket_name;
        _ = retention_days;
    }

    pub fn uploadFile(self: R2Client, key: []const u8, data: []const u8) !void {
        _ = self;
        _ = key;
        _ = data;
    }

    pub fn downloadFile(self: R2Client, key: []const u8, dest_path: []const u8) !void {
        _ = self;
        _ = key;
        _ = dest_path;
    }

    pub fn deleteFile(self: R2Client, key: []const u8) !void {
        _ = self;
        _ = key;
    }

    pub fn listObjects(self: R2Client, prefix: []const u8) !void {
        _ = self;
        _ = prefix;
    }
};
