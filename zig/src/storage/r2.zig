const std = @import("std");

pub const R2Backup = struct {
    endpoint: []const u8,
    bucket: []const u8,

    pub fn init(endpoint: []const u8, bucket: []const u8) R2Backup {
        return .{
            .endpoint = endpoint,
            .bucket = bucket,
        };
    }

    pub fn backupBundle(self: R2Backup, local_bundle_path: []const u8, s3_key: []const u8) !void {
        _ = self;
        _ = local_bundle_path;
        _ = s3_key;
    }
};
