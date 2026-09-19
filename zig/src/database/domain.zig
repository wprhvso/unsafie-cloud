const std = @import("std");

pub const DomainRecord = struct {
    id: [36]u8,
    user_id: i32,
    fqdn: []const u8,
    target_vm_id: [36]u8,
    target_port: u16,
    ssl_cert_pem: ?[]const u8,
    ssl_key_pem: ?[]const u8,
    status: []const u8,
};
