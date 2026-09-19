const std = @import("std");

pub const PortGrantRecord = struct {
    id: [36]u8,
    user_id: i32,
    node: []const u8,
    protocol: []const u8,
    host_port: u16,
};

pub const DomainGrantRecord = struct {
    id: [36]u8,
    user_id: i32,
    fqdn: []const u8,
};
