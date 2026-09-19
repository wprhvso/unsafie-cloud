const std = @import("std");

pub const NodeResult = struct {
    name: []const u8,
    ip_address: []const u8,
    total_ram_mb: i32,
    free_ram_mb: i32,
    active_vms: i32,
};
