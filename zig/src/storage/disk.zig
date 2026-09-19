const std = @import("std");

pub const DiskStorage = struct {
    base_dir: []const u8,

    pub fn init(base_dir: []const u8) DiskStorage {
        return .{ .base_dir = base_dir };
    }

    pub fn ensureDirs(self: DiskStorage) !void {
        try std.fs.cwd().makePath(self.base_dir);
    }
};
