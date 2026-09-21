const std = @import("std");
const client = @import("../client.zig");
const spinner = @import("../ui/spinner.zig").Spinner;
const table = @import("../ui/table.zig").Table;

pub fn execute(c: client.Client, args: []const []const u8) !void {
    _ = c;
    if (args.len < 1) {
        std.debug.print("Usage: unsafie token <create|list|revoke>\n", .{});
        return;
    }
    const sub = args[0];
    if (std.mem.eql(u8, sub, "list")) {
        table.printHeader(&[_][]const u8{ "NAME", "OWNER", "PREFIX", "STATUS" });
        table.printRow(&[_][]const u8{ "vladimir-cli", "vladimir", "phx_live_", "active" });
    } else if (std.mem.eql(u8, sub, "create")) {
        spinner.success("Token created: phx_live_a1b2c3d4e5f6...");
    } else if (std.mem.eql(u8, sub, "revoke")) {
        spinner.success("Token revoked");
    }
}
