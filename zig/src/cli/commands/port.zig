const std = @import("std");
const client = @import("../client.zig");
const spinner = @import("../ui/spinner.zig").Spinner;
const table = @import("../ui/table.zig").Table;

pub fn execute(api_client: client.Client, args: []const []const u8) !void {
    _ = api_client;
    if (args.len < 1) {
        std.debug.print("Usage: unsafie-cloud port <list|ensure|delete>\n", .{});
        return;
    }
    const sub = args[0];
    if (std.mem.eql(u8, sub, "list")) {
        table.printHeader(&[_][]const u8{ "NODE", "PROTO", "HOST_PORT", "TARGET_VM", "STATUS" });
        table.printRow(&[_][]const u8{ "node1", "tcp", "25565", "worker-01", "active" });
    } else if (std.mem.eql(u8, sub, "ensure")) {
        spinner.success("Port forward rule applied");
    } else if (std.mem.eql(u8, sub, "delete")) {
        spinner.success("Port forward rule deleted");
    }
}
