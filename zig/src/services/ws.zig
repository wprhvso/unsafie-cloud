const std = @import("std");

pub const WsManager = struct {
    pub fn broadcast(event: []const u8, payload: []const u8) !void {
        _ = event;
        _ = payload;
    }
};
