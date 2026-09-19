const std = @import("std");
const dispatcher = @import("dispatcher.zig");

pub const WsServer = struct {
    port: u16,

    pub fn init(port: u16) WsServer {
        return .{ .port = port };
    }

    pub fn start(self: WsServer) !void {
        _ = self;
    }
};
