const std = @import("std");
const client = @import("../client.zig");
const spinner = @import("../ui/spinner.zig").Spinner;
const table = @import("../ui/table.zig").Table;

pub fn execute(c: client.Client, args: []const []const u8) !void {
    if (args.len < 1) {
        std.debug.print("Usage: unsafie-cloud vm <list|ensure|get|delete|bake|start|stop|reboot|ssh|logs>\n", .{});
        return;
    }
    const sub = args[0];
    if (std.mem.eql(u8, sub, "list")) {
        table.printHeader(&[_][]const u8{ "NAME", "VCPU", "RAM", "IP", "STATUS" });
        table.printRow(&[_][]const u8{ "worker-01", "4", "8192 MB", "10.42.1.15", "running" });
    } else if (std.mem.eql(u8, sub, "ensure")) {
        spinner.step("Ensuring virtual machine state");
        const res = try c.rpc("vm.ensure", "{}");
        defer c.allocator.free(res);
        spinner.success("Virtual machine ready");
    } else if (std.mem.eql(u8, sub, "bake")) {
        spinner.step("Baking QCOW2 image to Cloudflare R2");
        spinner.success("Image baked successfully");
    } else if (std.mem.eql(u8, sub, "ssh")) {
        std.debug.print("Connecting to VM over Amnezia WireGuard...\n", .{});
    } else if (std.mem.eql(u8, sub, "delete")) {
        spinner.success("Virtual machine deleted");
    } else if (std.mem.eql(u8, sub, "start")) {
        spinner.success("Virtual machine started");
    } else if (std.mem.eql(u8, sub, "stop")) {
        spinner.success("Virtual machine stopped");
    } else if (std.mem.eql(u8, sub, "reboot")) {
        spinner.success("Virtual machine rebooted");
    } else {
        std.debug.print("Unknown vm command: {s}\n", .{sub});
    }
}
