const std = @import("std");

pub const UserResult = struct {
    id: i32,
    login: []const u8,
    email: []const u8,
    role: []const u8,
    is_active: bool,
};
