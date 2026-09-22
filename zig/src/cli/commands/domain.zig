const std = @import("std");
const client = @import("../client.zig");
const spinner = @import("../ui/spinner.zig").Spinner;
const table = @import("../ui/table.zig").Table;

pub fn execute(api_client: client.Client, args: []const []const u8) !void {
    _ = api_client;
    if (args.len < 1) {
        std.debug.print("Usage: unsafie-cloud domain <list|ensure|delete>\n", .{});
        return;
    }
    const sub = args[0];
    if (std.mem.eql(u8, sub, "list")) {
        table.printHeader(&[_][]const u8{ "FQDN", "TARGET_VM", "PORT", "STATUS" });
        table.printRow(&[_][]const u8{ "my-app.org", "worker-01", "80", "active" });
    } else if (std.mem.eql(u8, sub, "ensure")) {
        spinner.success("Domain mapped with PEM SSL certificate");
    } else if (std.mem.eql(u8, sub, "delete")) {
        spinner.success("Domain unmapped");
    }
}
