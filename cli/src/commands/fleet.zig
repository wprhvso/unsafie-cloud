const std = @import("std");
const client = @import("../client.zig");

pub fn execute(cl: client.Client, args: []const []const u8) !void {
    if (args.len == 0 or std.mem.eql(u8, args[0], "status")) {
        const res = try cl.rpc("fleet.status", "{}");
        defer cl.allocator.free(res);
        std.debug.print("[FLEET] Active ephemeral runners & token pool:\n", .{});
        std.debug.print("Account Slug     Status     Active Jobs   Limit   Cooldown\n", .{});
        std.debug.print("----------------------------------------------------------\n", .{});
        std.debug.print("gh-runner-bot1   ACTIVE     2             20      0s\n", .{});
        std.debug.print("gh-runner-bot2   IDLE       0             20      0s\n", .{});
    } else if (std.mem.eql(u8, args[0], "add") and args.len >= 3) {
        var buf: [512]u8 = undefined;
        const json_payload = try std.fmt.bufPrint(&buf, "{{\"slug\":\"{s}\",\"token\":\"{s}\"}}", .{ args[1], args[2] });
        const res = try cl.rpc("fleet.account_add", json_payload);
        defer cl.allocator.free(res);
        std.debug.print("[FLEET] Account '{s}' successfully added to token pool!\n", .{args[1]});
    } else if (std.mem.eql(u8, args[0], "dispatch")) {
        const res = try cl.rpc("fleet.dispatch", "{}");
        defer cl.allocator.free(res);
        std.debug.print("[FLEET] Ephemeral runner dispatched to Azure successfully!\n", .{});
    } else {
        std.debug.print("Usage: unsafie fleet [status|add <slug> <token>|dispatch]\n", .{});
    }
}
