const std = @import("std");

pub const Database = struct {
    allocator: std.mem.Allocator,
    connection_string: []const u8,

    pub fn init(allocator: std.mem.Allocator, conn_str: []const u8) Database {
        return .{
            .allocator = allocator,
            .connection_string = conn_str,
        };
    }

    pub fn execute(self: *Database, sql: []const u8) !void {
        _ = self;
        _ = sql;
    }
};
