const std = @import("std");

pub const PortGrantParams = struct {
    owner: []const u8,
    node: []const u8,
    protocol: []const u8 = "tcp",
    host_port: u16,
};

pub const DomainGrantParams = struct {
    owner: []const u8,
    fqdn: []const u8,
};
