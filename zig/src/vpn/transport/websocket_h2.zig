const std = @import("std");

pub const WebSocketH2 = struct {
    pub const Preface = "PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n";
    pub const WindowUpdateDelta: u32 = 15663105;

    pub fn generateSettingsFrame(out: []u8) !usize {
        if (out.len < 39) return error.BufferTooSmall;

        out[0] = 0x00;
        out[1] = 0x00;
        out[2] = 0x1e;
        out[3] = 0x04;
        out[4] = 0x00;
        out[5] = 0x00;
        out[6] = 0x00;
        out[7] = 0x00;
        out[8] = 0x00;

        const settings = [_][2]u32{
            .{ 0x0001, 65536 },
            .{ 0x0002, 0 },
            .{ 0x0003, 1000 },
            .{ 0x0004, 6291456 },
            .{ 0x0006, 262144 },
        };

        var offset: usize = 9;
        for (settings) |s| {
            out[offset] = @intCast((s[0] >> 8) & 0xff);
            out[offset + 1] = @intCast(s[0] & 0xff);
            out[offset + 2] = @intCast((s[1] >> 24) & 0xff);
            out[offset + 3] = @intCast((s[1] >> 16) & 0xff);
            out[offset + 4] = @intCast((s[1] >> 8) & 0xff);
            out[offset + 5] = @intCast(s[1] & 0xff);
            offset += 6;
        }

        return offset;
    }

    pub fn generateWindowUpdateFrame(stream_id: u32, increment: u32, out: []u8) !usize {
        if (out.len < 13) return error.BufferTooSmall;

        out[0] = 0x00;
        out[1] = 0x00;
        out[2] = 0x04;
        out[3] = 0x08;
        out[4] = 0x00;

        out[5] = @intCast((stream_id >> 24) & 0x7f);
        out[6] = @intCast((stream_id >> 16) & 0xff);
        out[7] = @intCast((stream_id >> 8) & 0xff);
        out[8] = @intCast(stream_id & 0xff);

        out[9] = @intCast((increment >> 24) & 0x7f);
        out[10] = @intCast((increment >> 16) & 0xff);
        out[11] = @intCast((increment >> 8) & 0xff);
        out[12] = @intCast(increment & 0xff);

        return 13;
    }

    pub fn packWsBinary(payload: []const u8, is_client: bool, out: []u8) !usize {
        var offset: usize = 0;
        out[offset] = 0x82;
        offset += 1;

        var mask_key: [4]u8 = undefined;
        if (is_client) {
            std.crypto.random.bytes(&mask_key);
        }

        if (payload.len < 126) {
            out[offset] = @intCast(if (is_client) 0x80 | payload.len else payload.len);
            offset += 1;
        } else if (payload.len <= 65535) {
            out[offset] = if (is_client) 0x80 | 126 else 126;
            out[offset + 1] = @intCast((payload.len >> 8) & 0xff);
            out[offset + 2] = @intCast(payload.len & 0xff);
            offset += 3;
        } else {
            out[offset] = if (is_client) 0x80 | 127 else 127;
            const dest_slice: *[8]u8 = out[offset + 1 .. offset + 9][0..8];
            std.mem.writeInt(u64, dest_slice, payload.len, .big);
            offset += 9;
        }

        if (is_client) {
            @memcpy(out[offset .. offset + 4], &mask_key);
            offset += 4;
            for (payload, 0..) |b, i| {
                out[offset + i] = b ^ mask_key[i % 4];
            }
        } else {
            @memcpy(out[offset .. offset + payload.len], payload);
        }
        offset += payload.len;

        return offset;
    }

    pub fn unpackWsBinary(in: []const u8, out: []u8) !usize {
        if (in.len < 2) return error.UnexpectedEof;
        const is_masked = (in[1] & 0x80) != 0;
        var len_val: usize = in[1] & 0x7f;
        var offset: usize = 2;

        if (len_val == 126) {
            if (in.len < 4) return error.UnexpectedEof;
            len_val = (@as(usize, in[2]) << 8) | in[3];
            offset = 4;
        } else if (len_val == 127) {
            if (in.len < 10) return error.UnexpectedEof;
            const src_slice: *const [8]u8 = in[2..10][0..8];
            len_val = @intCast(std.mem.readInt(u64, src_slice, .big));
            offset = 10;
        }

        if (out.len < len_val) return error.BufferTooSmall;

        if (is_masked) {
            if (in.len < offset + 4 + len_val) return error.UnexpectedEof;
            const mask = in[offset .. offset + 4];
            offset += 4;
            for (0..len_val) |i| {
                out[i] = in[offset + i] ^ mask[i % 4];
            }
        } else {
            if (in.len < offset + len_val) return error.UnexpectedEof;
            @memcpy(out[0..len_val], in[offset .. offset + len_val]);
        }

        return len_val;
    }
};
