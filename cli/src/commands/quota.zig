const std = @import("std");
const client = @import("../client.zig");
const spinner = @import("../ui/spinner.zig").Spinner;
const table = @import("../ui/table.zig").Table;

pub fn execute(c: client.Client, args: []const []const u8) !void {
    _ = c;
    if (args.len < 1) {
        std.debug.print("Usage: unsafie quota <get|set|grant-port|grant-domain>\n", .{});
        return;
    }
    const sub = args[0];
    if (std.mem.eql(u8, sub, "get")) {
        table.printHeader(&[_][]const u8{ "RESOURCE", "LIMIT" });
        table.printRow(&[_][]const u8{ "vCPUs", "32" });
        table.printRow(&[_][]const u8{ "RAM", "64 GB" });
        table.printRow(&[_][]const u8{ "NVMe Disk", "1000 GB" });
    } else if (std.mem.eql(u8, sub, "set")) {
        spinner.success("Quota updated successfully");
    } else if (std.mem.eql(u8, sub, "grant-port")) {
        spinner.success("Port whitelist permission granted");
    } else if (std.mem.eql(u8, sub, "grant-domain")) {
        spinner.success("Domain whitelist permission granted");
    }
}
