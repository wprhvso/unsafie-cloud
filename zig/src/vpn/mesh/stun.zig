const std = @import("std");

pub const Stun = struct {
    pub const MagicCookie: u32 = 0x2112A442;
    pub const MsgTypeBindingRequest: u16 = 0x0001;
    pub const MsgTypeBindingResponse: u16 = 0x0101;
    pub const AttrXorMappedAddress: u16 = 0x0020;

    pub fn buildBindingRequest(out: []u8, tx_id: *[12]u8) !usize {
        if (out.len < 20) return error.BufferTooSmall;
        std.crypto.random.bytes(tx_id);

        std.mem.writeInt(u16, out[0..2], MsgTypeBindingRequest, .big);
        std.mem.writeInt(u16, out[2..4], 0, .big);
        std.mem.writeInt(u32, out[4..8], MagicCookie, .big);
        @memcpy(out[8..20], tx_id);
        return 20;
    }

    pub fn buildBindingResponse(out: []u8, tx_id: [12]u8, client_ip: u32, client_port: u16) !usize {
        if (out.len < 32) return error.BufferTooSmall;

        std.mem.writeInt(u16, out[0..2], MsgTypeBindingResponse, .big);
        std.mem.writeInt(u16, out[2..4], 12, .big);
        std.mem.writeInt(u32, out[4..8], MagicCookie, .big);
        @memcpy(out[8..20], &tx_id);

        std.mem.writeInt(u16, out[20..22], AttrXorMappedAddress, .big);
        std.mem.writeInt(u16, out[22..24], 8, .big);
        out[24] = 0;
        out[25] = 1;

        const x_port = client_port ^ @as(u16, @intCast((MagicCookie >> 16) & 0xffff));
        std.mem.writeInt(u16, out[26..28], x_port, .big);

        const x_ip = client_ip ^ MagicCookie;
        std.mem.writeInt(u32, out[28..32], x_ip, .big);

        return 32;
    }

    pub fn parseBindingResponse(in: []const u8, expected_tx_id: [12]u8) !struct { ip: u32, port: u16 } {
        if (in.len < 32) return error.UnexpectedEof;
        const msg_type = std.mem.readInt(u16, in[0..2], .big);
        if (msg_type != MsgTypeBindingResponse) return error.InvalidMessageType;

        const cookie = std.mem.readInt(u32, in[4..8], .big);
        if (cookie != MagicCookie) return error.InvalidMagicCookie;

        if (!std.mem.eql(u8, in[8..20], &expected_tx_id)) return error.TxIdMismatch;

        var offset: usize = 20;
        while (offset + 4 <= in.len) {
            const attr_type = std.mem.readInt(u16, in[offset .. offset + 2][0..2], .big);
            const attr_len = std.mem.readInt(u16, in[offset + 2 .. offset + 4][0..2], .big);
            offset += 4;

            if (attr_type == AttrXorMappedAddress and attr_len == 8) {
                const family = in[offset + 1];
                if (family != 1) return error.UnsupportedAddressFamily;

                const x_port = std.mem.readInt(u16, in[offset + 2 .. offset + 4][0..2], .big);
                const port = x_port ^ @as(u16, @intCast((MagicCookie >> 16) & 0xffff));

                const x_ip = std.mem.readInt(u32, in[offset + 4 .. offset + 8][0..4], .big);
                const ip = x_ip ^ MagicCookie;

                return .{ .ip = ip, .port = port };
            }
            offset += attr_len;
        }

        return error.AttributeNotFound;
    }
};
