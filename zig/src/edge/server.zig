const std = @import("std");
const listener_tcp = @import("listener_tcp.zig");
const listener_udp = @import("listener_udp.zig");

pub const EdgeServer = struct {
    http_port: u16,
    https_port: u16,

    pub fn init(http_port: u16, https_port: u16) EdgeServer {
        return .{
            .http_port = http_port,
            .https_port = https_port,
        };
    }

    pub fn start(self: EdgeServer) !void {
        _ = self;
    }
};
