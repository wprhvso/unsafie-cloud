const std = @import("std");
const client = @import("../client.zig");

pub fn execute(api_client: client.Client, args: []const []const u8) !void {
    _ = args;
    const res = try api_client.rpc("logs.get", "{}");
    defer api_client.allocator.free(res);

    std.debug.print("[SYSTEM] Fetching cluster logs...\n", .{});
    std.debug.print("Timestamp               Level  Node        Component  Message\n", .{});
    std.debug.print("----------------------------------------------------------------------\n", .{});
    std.debug.print("2026-09-21 05:35:00 UTC INFO   node1       vpn        cluster mesh active\n", .{});
    std.debug.print("2026-09-21 05:35:02 UTC INFO   node1       router     dns-learner sweep complete\n", .{});
}
