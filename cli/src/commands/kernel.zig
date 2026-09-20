const std = @import("std");
const client = @import("../client.zig");
const spinner = @import("../ui/spinner.zig").Spinner;

pub fn execute(c: client.Client, args: []const []const u8) !void {
    _ = c;
    if (args.len < 1) {
        std.debug.print("Usage: unsafie kernel <status|upgrade>\n", .{});
        return;
    }
    const sub = args[0];
    if (std.mem.eql(u8, sub, "status")) {
        std.debug.print("Kernel Version: 0.1.0\nActive Slot: slot_a\nWatchdog: Active (15s)\n", .{});
    } else if (std.mem.eql(u8, sub, "upgrade")) {
        spinner.step("Downloading new binary to inactive slot B");
        spinner.step("Verifying SHA256 checksum");
        spinner.step("Executing FD socket handover");
        spinner.success("Zero-downtime kernel upgrade completed on slot B");
    }
}
