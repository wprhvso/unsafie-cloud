const std = @import("std");

pub const TokenHandler = struct {
    pub fn handleEnsure(allocator: std.mem.Allocator, params: ?std.json.Value) !std.json.Value {
        _ = allocator;
        _ = params;
        return std.json.Value{ .string = "token_created" };
    }

    pub fn handleRevoke(allocator: std.mem.Allocator, params: ?std.json.Value) !std.json.Value {
        _ = allocator;
        _ = params;
        return std.json.Value{ .string = "token_revoked" };
    }
};
