const std = @import("std");

pub const SniResolver = struct {
    pub fn resolveCertPath(allocator: std.mem.Allocator, fqdn: []const u8) ![]const u8 {
        return try std.fmt.allocPrint(allocator, "/etc/ssl/domains/{s}.crt", .{fqdn});
    }

    pub fn resolveKeyPath(allocator: std.mem.Allocator, fqdn: []const u8) ![]const u8 {
        return try std.fmt.allocPrint(allocator, "/etc/ssl/domains/{s}.key", .{fqdn});
    }
};
