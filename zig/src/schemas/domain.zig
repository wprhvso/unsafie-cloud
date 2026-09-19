const std = @import("std");

pub const DomainEnsureParams = struct {
    fqdn: []const u8,
    target_vm: []const u8,
    target_port: u16 = 80,
    ssl_cert_pem: ?[]const u8 = null,
    ssl_key_pem: ?[]const u8 = null,
};

pub const DomainResult = struct {
    id: []const u8,
    fqdn: []const u8,
    target_port: u16,
    status: []const u8,
};
