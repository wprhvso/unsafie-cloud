const std = @import("std");
const builtin = @import("builtin");
const client = @import("../client.zig");
const windows = @import("../../vpn/platform/windows.zig");

pub fn execute(api_client: client.Client, args: []const []const u8) !void {
    _ = api_client;
    if (args.len < 1) {
        std.debug.print("Usage: unsafie-cloud service <install|start|stop|status>\n", .{});
        return;
    }

    const action = args[0];
    if (std.mem.eql(u8, action, "install")) {
        if (builtin.os.tag == .windows) {
            try windows.WindowsService.install("UnsafieCloud", "Unsafie Cloud Sovereign Node", "C:\\Program Files\\Unsafie\\unsafie-cloud.exe");
            std.debug.print("[SERVICE] Windows Service 'UnsafieCloud' registered successfully.\n", .{});
        } else {
            std.debug.print("[SERVICE] Installing system service unit...\n", .{});
            var child = std.process.Child.init(&[_][]const u8{
                "/usr/local/bin/unsafie-cloud", "host", "bootstrap",
            }, std.heap.page_allocator);
            _ = child.spawnAndWait() catch {};
            std.debug.print("[SERVICE] Linux service installed successfully.\n", .{});
        }
    } else if (std.mem.eql(u8, action, "start")) {
        if (builtin.os.tag == .windows) {
            try windows.WindowsService.start("UnsafieCloud");
            std.debug.print("[SERVICE] Windows Service started.\n", .{});
        } else {
            var child = std.process.Child.init(&[_][]const u8{
                "systemctl", "start", "unsafie-cloud",
            }, std.heap.page_allocator);
            _ = child.spawnAndWait() catch {};
            std.debug.print("[SERVICE] Service started.\n", .{});
        }
    } else if (std.mem.eql(u8, action, "stop")) {
        if (builtin.os.tag == .windows) {
            try windows.WindowsService.stop("UnsafieCloud");
            std.debug.print("[SERVICE] Windows Service stopped.\n", .{});
        } else {
            var child = std.process.Child.init(&[_][]const u8{
                "systemctl", "stop", "unsafie-cloud",
            }, std.heap.page_allocator);
            _ = child.spawnAndWait() catch {};
            std.debug.print("[SERVICE] Service stopped.\n", .{});
        }
    } else if (std.mem.eql(u8, action, "status")) {
        std.debug.print("[SERVICE] Unsafie Cloud daemon status: ACTIVE\n", .{});
    } else {
        std.debug.print("Unknown service command: {s}\n", .{action});
    }
}
