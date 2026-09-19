const std = @import("std");

pub const IsoHandler = struct {
    pub fn handleEnsure(allocator: std.mem.Allocator, params: ?std.json.Value) !std.json.Value {
        _ = allocator;
        _ = params;
        return std.json.Value{ .string = "iso_ready" };
    }

    pub fn handleList(allocator: std.mem.Allocator) !std.json.Value {
        const map = std.json.Array.init(allocator);
        return std.json.Value{ .array = map };
    }
};
