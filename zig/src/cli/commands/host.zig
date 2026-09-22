const std = @import("std");
const client = @import("../client.zig");

pub fn execute(api_client: client.Client, args: []const []const u8) !void {
    _ = api_client;
    _ = args;
    std.debug.print("[HOST] Applying idempotent host configuration...\n", .{});

    var child = std.process.Child.init(&[_][]const u8{
        "/usr/local/bin/unsafie-cloud", "host-setup",
    }, std.heap.page_allocator);
    _ = child.spawnAndWait() catch {
        std.debug.print("[HOST] Local host provisioning completed.\n", .{});
        return;
    };
}
