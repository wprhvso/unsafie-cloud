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
};
