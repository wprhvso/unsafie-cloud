const std = @import("std");
const ws_h2 = @import("../vpn/transport/websocket_h2.zig");

pub const TcpListener = struct {
    port: u16,

    pub fn init(port: u16) TcpListener {
        return .{ .port = port };
    }

    pub fn listen(self: TcpListener) !void {
        _ = self;
    }

    pub fn handleWsFrame(self: TcpListener, frame: []const u8, out_buf: []u8) !?[]const u8 {
        _ = self;
        const len = ws_h2.WebSocketH2.unpackWsBinary(frame, out_buf) catch return null;
        return out_buf[0..len];
    }
};
