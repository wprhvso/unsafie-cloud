const std = @import("std");

pub const SystemdWatchdog = struct {
    pub fn notifyReady() void {
        sendNotify("READY=1") catch {};
    }

    pub fn notifyWatchdog() void {
        sendNotify("WATCHDOG=1") catch {};
    }

    fn sendNotify(state: []const u8) !void {
        const notify_socket = std.posix.getenv("NOTIFY_SOCKET") orelse return;
        const stream = try std.net.connectUnixSocket(notify_socket);
        defer stream.close();
        _ = try stream.write(state);
    }
};
