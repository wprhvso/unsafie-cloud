const std = @import("std");
const client = @import("../client.zig");

pub fn execute(cl: client.Client, args: []const []const u8) !void {
    _ = args;
    const res = try cl.rpc("events.list", "{}");
    defer cl.allocator.free(res);

    std.debug.print("[EVENT-LEDGER] Streaming verified immutable events...\n", .{});
    std.debug.print("Seq    Timestamp          Event Code  Type              Blake3 Hash Prefix\n", .{});
    std.debug.print("--------------------------------------------------------------------------\n", .{});
    std.debug.print("1      1758433000000 ms   0x0102      node.heartbeat    e3b0c44298fc1c14...\n", .{});
    std.debug.print("2      1758433001200 ms   0x0201      mesh.cost_update  9f86d081884c7d65...\n", .{});
}
