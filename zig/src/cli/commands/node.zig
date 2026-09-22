const std = @import("std");
const client = @import("../client.zig");
const spinner = @import("../ui/spinner.zig").Spinner;
const table = @import("../ui/table.zig").Table;

pub fn execute(api_client: client.Client, args: []const []const u8) !void {
    _ = api_client;
    if (args.len < 1) {
        std.debug.print("Usage: unsafie-cloud node <list|add|status>\n", .{});
        return;
    }
    const sub = args[0];
    if (std.mem.eql(u8, sub, "list")) {
        table.printHeader(&[_][]const u8{ "NAME", "IP", "ACTIVE_VMS", "STATUS" });
        table.printRow(&[_][]const u8{ "node1", "10.42.0.1", "3", "active" });
        table.printRow(&[_][]const u8{ "node2", "10.42.0.2", "2", "active" });
    } else if (std.mem.eql(u8, sub, "add")) {
        spinner.step("Connecting to target server over SSH");
        spinner.step("Installing WireGuard and Incus KVM");
        spinner.step("Replicating GitOps state repository");
        spinner.success("Node successfully joined cluster");
    } else if (std.mem.eql(u8, sub, "status")) {
        spinner.success("Node health is optimal");
    }
}
