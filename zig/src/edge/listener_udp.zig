const std = @import("std");
const masque = @import("../vpn/transport/masque.zig");

pub const UdpListener = struct {
    port: u16,

    pub fn init(port: u16) UdpListener {
        return .{ .port = port };
    }

    pub fn listen(self: UdpListener) !void {
        _ = self;
    }

    pub fn handlePacket(self: UdpListener, packet: []const u8, out_buf: []u8) !?[]const u8 {
        _ = self;
        const unpacked = masque.Masque.unpackDatagram(packet) catch return null;
        if (unpacked.context_id == 0) {
            @memcpy(out_buf[0..unpacked.payload.len], unpacked.payload);
            return out_buf[0..unpacked.payload.len];
        }
        return null;
    }
};
