const std = @import("std");

pub const DomainService = struct {
    pub fn saveCertificates(fqdn: []const u8, cert_pem: ?[]const u8, key_pem: ?[]const u8) !void {
        _ = fqdn;
        _ = cert_pem;
        _ = key_pem;
    }
};
