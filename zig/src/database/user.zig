const std = @import("std");

pub const User = struct {
    id: i32,
    login: []const u8,
    email: []const u8,
    role: []const u8,
    is_active: bool,
};

pub const Quota = struct {
    max_vcpus: i32,
    max_ram_mb: i32,
    max_disk_gb: i32,
    max_vms: i32,
};
