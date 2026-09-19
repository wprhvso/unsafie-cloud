const std = @import("std");

pub const PortService = struct {
    pub fn forward(node: []const u8, host_port: u16, target_port: u16) !void {
        _ = node;
        _ = host_port;
        _ = target_port;
    }
};
