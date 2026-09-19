const std = @import("std");

pub const PortRecord = struct {
    id: [36]u8,
    user_id: i32,
    node: []const u8,
    protocol: []const u8,
    host_port: u16,
    target_vm_id: [36]u8,
    target_port: u16,
    status: []const u8,
};
