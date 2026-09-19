const std = @import("std");

pub const Session = struct {
    id: []const u8,
    user_id: i32,
    is_admin: bool,

    pub fn requireAdmin(self: Session) !void {
        if (!self.is_admin) return error.AccessDenied;
    }
};
