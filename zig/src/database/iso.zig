const std = @import("std");

pub const IsoRecord = struct {
    id: [36]u8,
    user_id: i32,
    name: []const u8,
    is_shared: bool,
    source_url: ?[]const u8,
    r2_storage_key: []const u8,
    size_bytes: i64,
    status: []const u8,
};
