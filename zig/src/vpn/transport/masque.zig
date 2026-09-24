const std = @import("std");

pub const Masque = struct {
    pub const FrameTypeDatagram: u64 = 0x30;
    pub const FrameTypeDatagramLen: u64 = 0x31;

    pub fn encodeVarint(val: u64, out: []u8) !usize {
        if (val < 64) {
            if (out.len < 1) return error.BufferTooSmall;
            out[0] = @intCast(val);
            return 1;
        } else if (val < 16384) {
            if (out.len < 2) return error.BufferTooSmall;
            out[0] = @intCast(0x40 | ((val >> 8) & 0x3f));
            out[1] = @intCast(val & 0xff);
            return 2;
        } else if (val < 1073741824) {
            if (out.len < 4) return error.BufferTooSmall;
            out[0] = @intCast(0x80 | ((val >> 24) & 0x3f));
            out[1] = @intCast((val >> 16) & 0xff);
            out[2] = @intCast((val >> 8) & 0xff);
            out[3] = @intCast(val & 0xff);
            return 4;
        } else {
            if (out.len < 8) return error.BufferTooSmall;
            out[0] = @intCast(0xc0 | ((val >> 56) & 0x3f));
            out[1] = @intCast((val >> 48) & 0xff);
            out[2] = @intCast((val >> 40) & 0xff);
            out[3] = @intCast((val >> 32) & 0xff);
            out[4] = @intCast((val >> 24) & 0xff);
            out[5] = @intCast((val >> 16) & 0xff);
            out[6] = @intCast((val >> 8) & 0xff);
            out[7] = @intCast(val & 0xff);
            return 8;
        }
    }

    pub fn decodeVarint(in: []const u8) !struct { val: u64, len: usize } {
        if (in.len < 1) return error.UnexpectedEof;
        const prefix = in[0] >> 6;
        switch (prefix) {
            0 => return .{ .val = in[0], .len = 1 },
            1 => {
                if (in.len < 2) return error.UnexpectedEof;
                const v = (@as(u64, in[0] & 0x3f) << 8) | in[1];
                return .{ .val = v, .len = 2 };
            },
            2 => {
                if (in.len < 4) return error.UnexpectedEof;
                const v = (@as(u64, in[0] & 0x3f) << 24) |
                    (@as(u64, in[1]) << 16) |
                    (@as(u64, in[2]) << 8) |
                    in[3];
                return .{ .val = v, .len = 4 };
            },
            3 => {
                if (in.len < 8) return error.UnexpectedEof;
                const v = (@as(u64, in[0] & 0x3f) << 56) |
                    (@as(u64, in[1]) << 48) |
                    (@as(u64, in[2]) << 40) |
                    (@as(u64, in[3]) << 32) |
                    (@as(u64, in[4]) << 24) |
                    (@as(u64, in[5]) << 16) |
                    (@as(u64, in[6]) << 8) |
                    in[7];
                return .{ .val = v, .len = 8 };
            },
            else => unreachable,
        }
    }

    pub fn packDatagram(context_id: u64, payload: []const u8, out: []u8) !usize {
        var offset: usize = 0;

        const ft_len = try encodeVarint(FrameTypeDatagramLen, out[offset..]);
        offset += ft_len;

        var temp: [8]u8 = undefined;
        const ctx_len = try encodeVarint(context_id, &temp);
        const total_len = ctx_len + payload.len;

        const len_bytes = try encodeVarint(total_len, out[offset..]);
        offset += len_bytes;

        const ctx_bytes = try encodeVarint(context_id, out[offset..]);
        offset += ctx_bytes;

        if (out.len < offset + payload.len) return error.BufferTooSmall;
        @memcpy(out[offset .. offset + payload.len], payload);
        offset += payload.len;

        return offset;
    }

    pub fn unpackDatagram(in: []const u8) !struct { context_id: u64, payload: []const u8 } {
        var offset: usize = 0;
        const ft = try decodeVarint(in[offset..]);
        offset += ft.len;

        if (ft.val == FrameTypeDatagramLen) {
            const length_field = try decodeVarint(in[offset..]);
            offset += length_field.len;
        }

        const ctx = try decodeVarint(in[offset..]);
        offset += ctx.len;

        return .{
            .context_id = ctx.val,
            .payload = in[offset..],
        };
    }

    pub fn packSecure(key: [32]u8, nonce_counter: u64, context_id: u64, payload: []const u8, out: []u8) !usize {
        if (out.len < 24 + 16 + payload.len) return error.BufferTooSmall;

        var plain_buf: [2048]u8 = undefined;
        const plain_len = try packDatagram(context_id, payload, &plain_buf);

        std.mem.writeInt(u64, out[0..8][0..8], nonce_counter, .little);

        var nonce = [_]u8{0} ** 12;
        std.mem.writeInt(u64, nonce[4..12][0..8], nonce_counter, .little);

        var tag: [16]u8 = undefined;
        std.crypto.aead.chacha_poly.ChaCha20Poly1305.encrypt(out[24 .. 24 + plain_len], &tag, plain_buf[0..plain_len], out[0..8], nonce, key);
        @memcpy(out[8..24], &tag);

        return 24 + plain_len;
    }

    pub fn unpackSecure(key: [32]u8, in: []const u8, out: []u8) !struct { context_id: u64, payload_len: usize } {
        if (in.len < 24) return error.PacketTooShort;

        const nonce_counter = std.mem.readInt(u64, in[0..8][0..8], .little);
        var tag: [16]u8 = undefined;
        @memcpy(&tag, in[8..24]);

        var nonce = [_]u8{0} ** 12;
        std.mem.writeInt(u64, nonce[4..12][0..8], nonce_counter, .little);

        var plain_buf: [2048]u8 = undefined;
        const cipher = in[24..];
        if (plain_buf.len < cipher.len) return error.BufferTooSmall;

        try std.crypto.aead.chacha_poly.ChaCha20Poly1305.decrypt(plain_buf[0..cipher.len], cipher, tag, in[0..8], nonce, key);
        const unpacked = try unpackDatagram(plain_buf[0..cipher.len]);

        if (out.len < unpacked.payload.len) return error.BufferTooSmall;
        @memcpy(out[0..unpacked.payload.len], unpacked.payload);

        return .{
            .context_id = unpacked.context_id,
            .payload_len = unpacked.payload.len,
        };
    }
};

test "masque secure datagram roundtrip" {
    const key = [_]u8{0x42} ** 32;
    const test_payload = "test-ip-packet-content";
    var packet_buf: [512]u8 = undefined;

    const enc_len = try Masque.packSecure(key, 101, 0, test_payload, &packet_buf);
    try std.testing.expect(enc_len > test_payload.len);

    var dec_buf: [512]u8 = undefined;
    const res = try Masque.unpackSecure(key, packet_buf[0..enc_len], &dec_buf);

    try std.testing.expectEqual(@as(u64, 0), res.context_id);
    try std.testing.expectEqualStrings(test_payload, dec_buf[0..res.payload_len]);
}
