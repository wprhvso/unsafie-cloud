const std = @import("std");

pub const AdminService = struct {
    pub fn verifyAdmin(token: []const u8, admin_token: []const u8) bool {
        return std.mem.eql(u8, token, admin_token);
    }
};
