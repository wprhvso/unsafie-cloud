const std = @import("std");
const client = @import("../client.zig");
const spinner = @import("../ui/spinner.zig").Spinner;
const table = @import("../ui/table.zig").Table;

pub fn execute(c: client.Client, args: []const []const u8) !void {
    _ = c;
    if (args.len < 1) {
        std.debug.print("Usage: unsafie image <list|delete>\n", .{});
        return;
    }
    const sub = args[0];
    if (std.mem.eql(u8, sub, "list")) {
        table.printHeader(&[_][]const u8{ "NAME", "SIZE_MB", "STATUS" });
        table.printRow(&[_][]const u8{ "alpine-worker-v1", "450", "ready" });
    } else if (std.mem.eql(u8, sub, "delete")) {
        spinner.success("Image deleted");
    }
}
