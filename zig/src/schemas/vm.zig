const std = @import("std");

pub const VmEnsureParams = struct {
    name: []const u8,
    vcpus: i32 = 2,
    ram_mb: i32 = 4096,
    disk_gb: i32 = 30,
    image: ?[]const u8 = null,
    iso: ?[]const u8 = null,
    tasks: ?std.json.Value = null,
};

pub const VmResult = struct {
    id: []const u8,
    name: []const u8,
    vcpus: i32,
    ram_mb: i32,
    disk_gb: i32,
    ip_address: ?[]const u8 = null,
    status: []const u8,
};
