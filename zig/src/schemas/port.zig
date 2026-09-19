const std = @import("std");

pub const PortEnsureParams = struct {
    node: []const u8,
    protocol: []const u8 = "tcp",
    host_port: u16,
    target_vm: []const u8,
    target_port: u16,
};

pub const PortResult = struct {
    id: []const u8,
    node: []const u8,
    protocol: []const u8,
    host_port: u16,
    target_port: u16,
    status: []const u8,
};
