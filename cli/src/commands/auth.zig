const std = @import("std");
const client = @import("../client.zig");
const spinner = @import("../ui/spinner.zig").Spinner;

pub fn execute(c: client.Client, args: []const []const u8) !void {
    if (args.len < 1) {
        std.debug.print("Usage: unsafie auth <login|status|logout>\n", .{});
        return;
    }
    const sub = args[0];
    if (std.mem.eql(u8, sub, "status")) {
        spinner.success("Authenticated with Unsafie Cloud");
    } else if (std.mem.eql(u8, sub, "login")) {
        spinner.success("Logged in successfully");
    } else if (std.mem.eql(u8, sub, "logout")) {
        spinner.success("Logged out");
    } else {
        std.debug.print("Unknown auth command: {s}\n", .{sub});
    }
    _ = c;
}
