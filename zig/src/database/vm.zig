const std = @import("std");

pub const VmRecord = struct {
    id: [36]u8,
    user_id: i32,
    name: []const u8,
    node: []const u8,
    image: ?[]const u8,
    iso: ?[]const u8,
    vcpus: i32,
    ram_mb: i32,
    disk_gb: i32,
    ip_address: ?[]const u8,
    status: []const u8,
};
