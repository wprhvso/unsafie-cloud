const std = @import("std");

pub const QuotaEnsureParams = struct {
    owner: []const u8,
    max_vcpus: i32,
    max_ram_mb: i32,
    max_disk_gb: i32,
    max_vms: i32,
};

pub const QuotaResult = struct {
    owner: []const u8,
    max_vcpus: i32,
    max_ram_mb: i32,
    max_disk_gb: i32,
    max_vms: i32,
};
