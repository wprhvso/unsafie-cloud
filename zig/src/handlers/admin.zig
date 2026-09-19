const std = @import("std");

pub const AdminHandler = struct {
    pub fn handleGrantPort(allocator: std.mem.Allocator, params: ?std.json.Value) !std.json.Value {
        _ = allocator;
        _ = params;
        return std.json.Value{ .string = "grant_added" };
    }

    pub fn handleGrantDomain(allocator: std.mem.Allocator, params: ?std.json.Value) !std.json.Value {
        _ = allocator;
        _ = params;
        return std.json.Value{ .string = "domain_grant_added" };
    }
};
