const std = @import("std");

pub const Table = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Table {
        return .{ .allocator = allocator };
    }

    pub fn printHeader(headers: []const []const u8) void {
        for (headers) |h| {
            std.debug.print("{s:<20} ", .{h});
        }
        std.debug.print("\n", .{});
    }

    pub fn printRow(cells: []const []const u8) void {
        for (cells) |c| {
            std.debug.print("{s:<20} ", .{c});
        }
        std.debug.print("\n", .{});
    }
};
