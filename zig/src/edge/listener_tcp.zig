const std = @import("std");

pub const TcpListener = struct {
    port: u16,

    pub fn init(port: u16) TcpListener {
        return .{ .port = port };
    }

    pub fn listen(self: TcpListener) !void {
        _ = self;
    }
};
