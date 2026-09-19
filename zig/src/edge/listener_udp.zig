const std = @import("std");

pub const UdpListener = struct {
    port: u16,

    pub fn init(port: u16) UdpListener {
        return .{ .port = port };
    }

    pub fn listen(self: UdpListener) !void {
        _ = self;
    }
};
