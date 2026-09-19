const std = @import("std");

pub const DomainHandler = struct {
    pub fn handleEnsure(allocator: std.mem.Allocator, params: ?std.json.Value) !std.json.Value {
        _ = allocator;
        _ = params;
        return std.json.Value{ .string = "domain_active" };
    }

    pub fn handleDelete(allocator: std.mem.Allocator, params: ?std.json.Value) !std.json.Value {
        _ = allocator;
        _ = params;
        return std.json.Value{ .string = "domain_deleted" };
    }
};
