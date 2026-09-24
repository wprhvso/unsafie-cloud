const std = @import("std");
const listener_tcp = @import("listener_tcp.zig");
const listener_udp = @import("listener_udp.zig");
const tun = @import("../vpn/tun.zig");
const logger_mod = @import("../logging/logger.zig");

pub const EdgeServer = struct {
    http_port: u16,
    https_port: u16,
    udp_listener: listener_udp.UdpListener,
    tcp_listener: listener_tcp.TcpListener,

    pub fn init(http_port: u16, https_port: u16) EdgeServer {
        return .{
            .http_port = http_port,
            .https_port = https_port,
            .udp_listener = listener_udp.UdpListener.init(https_port),
            .tcp_listener = listener_tcp.TcpListener.init(https_port),
        };
    }

    pub fn setLogger(self: *EdgeServer, l: *logger_mod.StructuredLogger) void {
        self.udp_listener.logger = l;
    }

    pub fn start(self: *EdgeServer, key: [32]u8, tun_dev: *tun.TunDevice) !void {
        self.udp_listener.start(key, tun_dev) catch {};
        self.tcp_listener.start(key, tun_dev) catch {};
    }

    pub fn stop(self: *EdgeServer) void {
        self.udp_listener.stop();
        self.tcp_listener.stop();
    }

    pub fn sendPacket(self: *EdgeServer, payload: []const u8) !void {
        try self.udp_listener.sendToClient(payload);
    }
};
