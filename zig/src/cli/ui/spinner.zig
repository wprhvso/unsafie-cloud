const std = @import("std");

pub const Spinner = struct {
    pub fn step(message: []const u8) void {
        std.debug.print("[*] {s}...\n", .{message});
    }

    pub fn success(message: []const u8) void {
        std.debug.print("[✔] {s}\n", .{message});
    }

    pub fn fail(message: []const u8) void {
        std.debug.print("[✘] {s}\n", .{message});
    }
};
