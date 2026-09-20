const std = @import("std");
const client = @import("../client.zig");

pub fn execute(c: client.Client, args: []const []const u8) !void {
    _ = c;
    _ = args;
    std.debug.print("+------------------ Unsafie Cloud TUI ------------------+\n", .{});
    std.debug.print("| Nodes: 3/3 Online | Active VMs: 4 | Domains: 2        |\n", .{});
    std.debug.print("+-------------------------------------------------------+\n", .{});
    std.debug.print("| NAME         VCPU   RAM       IP            STATUS    |\n", .{});
    std.debug.print("| worker-01    4      8192 MB   10.42.1.15    RUNNING   |\n", .{});
    std.debug.print("| worker-02    2      4096 MB   10.42.1.16    RUNNING   |\n", .{});
    std.debug.print("+-------------------------------------------------------+\n", .{});
}
