const std = @import("std");
const grease = @import("grease.zig");

pub const ChromeClientHello = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) ChromeClientHello {
        return .{ .allocator = allocator };
    }

    pub fn generate(self: ChromeClientHello, sni_hostname: []const u8, alpn_mode: enum { h3, h2 }) ![]u8 {
        var buf = std.ArrayList(u8){};
        errdefer buf.deinit(self.allocator);

        const grease_cipher = grease.Grease.randomValue();
        const grease_group = grease.Grease.randomValue();
        const grease_ext = grease.Grease.randomValue();
        const grease_version = grease.Grease.randomValue();

        try buf.append(self.allocator, 0x16);
        try buf.append(self.allocator, 0x03);
        try buf.append(self.allocator, 0x01);
        try buf.append(self.allocator, 0x00);
        try buf.append(self.allocator, 0x00);

        const hs_start = buf.items.len;
        try buf.append(self.allocator, 0x01);
        try buf.append(self.allocator, 0x00);
        try buf.append(self.allocator, 0x00);
        try buf.append(self.allocator, 0x00);

        try buf.append(self.allocator, 0x03);
        try buf.append(self.allocator, 0x03);

        var random_bytes: [32]u8 = undefined;
        std.crypto.random.bytes(&random_bytes);
        try buf.appendSlice(self.allocator, &random_bytes);

        try buf.append(self.allocator, 32);
        var session_id: [32]u8 = undefined;
        std.crypto.random.bytes(&session_id);
        try buf.appendSlice(self.allocator, &session_id);

        const standard_ciphers = [_]u16{
            0x1301, 0x1302, 0x1303,
            0xc02b, 0xc02f, 0xc02c, 0xc030,
            0xcca9, 0xcca8,
            0x009c, 0x009d,
            0x002f, 0x0035, 0x000a,
        };

        const cipher_suites_len: u16 = (1 + standard_ciphers.len) * 2;
        try appendU16(&buf, self.allocator, cipher_suites_len);
        try appendU16(&buf, self.allocator, grease_cipher);
        for (standard_ciphers) |c| {
            try appendU16(&buf, self.allocator, c);
        }

        try buf.append(self.allocator, 1);
        try buf.append(self.allocator, 0);

        const ext_len_offset = buf.items.len;
        try buf.append(self.allocator, 0x00);
        try buf.append(self.allocator, 0x00);
        const ext_start = buf.items.len;

        try appendU16(&buf, self.allocator, 0x0000);
        const sni_ext_len = 2 + 1 + 2 + sni_hostname.len;
        try appendU16(&buf, self.allocator, @intCast(sni_ext_len));
        try appendU16(&buf, self.allocator, @intCast(sni_hostname.len + 3));
        try buf.append(self.allocator, 0x00);
        try appendU16(&buf, self.allocator, @intCast(sni_hostname.len));
        try buf.appendSlice(self.allocator, sni_hostname);

        try appendU16(&buf, self.allocator, 0x0017);
        try appendU16(&buf, self.allocator, 0x0000);

        try appendU16(&buf, self.allocator, 0xff01);
        try appendU16(&buf, self.allocator, 0x0001);
        try buf.append(self.allocator, 0x00);

        try appendU16(&buf, self.allocator, 0x000a);
        const groups = [_]u16{ grease_group, 0x11ec, 0x001d, 0x0017, 0x0018 };
        try appendU16(&buf, self.allocator, @intCast(2 + groups.len * 2));
        try appendU16(&buf, self.allocator, @intCast(groups.len * 2));
        for (groups) |g| try appendU16(&buf, self.allocator, g);

        try appendU16(&buf, self.allocator, 0x000b);
        try appendU16(&buf, self.allocator, 2);
        try buf.append(self.allocator, 1);
        try buf.append(self.allocator, 0x00);

        try appendU16(&buf, self.allocator, 0x0023);
        try appendU16(&buf, self.allocator, 0x0000);

        try appendU16(&buf, self.allocator, 0x0010);
        if (alpn_mode == .h3) {
            try appendU16(&buf, self.allocator, 5);
            try appendU16(&buf, self.allocator, 3);
            try buf.append(self.allocator, 2);
            try buf.appendSlice(self.allocator, "h3");
        } else {
            try appendU16(&buf, self.allocator, 14);
            try appendU16(&buf, self.allocator, 12);
            try buf.append(self.allocator, 2);
            try buf.appendSlice(self.allocator, "h2");
            try buf.append(self.allocator, 8);
            try buf.appendSlice(self.allocator, "http/1.1");
        }

        try appendU16(&buf, self.allocator, 0x0005);
        try appendU16(&buf, self.allocator, 5);
        try buf.append(self.allocator, 0x01);
        try appendU16(&buf, self.allocator, 0x0000);
        try appendU16(&buf, self.allocator, 0x0000);

        try appendU16(&buf, self.allocator, 0x000d);
        const sig_algs = [_]u16{ 0x0403, 0x0804, 0x0401, 0x0503, 0x0805, 0x0501, 0x0806, 0x0601 };
        try appendU16(&buf, self.allocator, @intCast(2 + sig_algs.len * 2));
        try appendU16(&buf, self.allocator, @intCast(sig_algs.len * 2));
        for (sig_algs) |s| try appendU16(&buf, self.allocator, s);

        try appendU16(&buf, self.allocator, 0x0012);
        try appendU16(&buf, self.allocator, 0x0000);

        try appendU16(&buf, self.allocator, 0x0033);
        const ks_len = 2 + (4 + 1) + (4 + 32);
        try appendU16(&buf, self.allocator, @intCast(ks_len));
        try appendU16(&buf, self.allocator, @intCast(ks_len - 2));

        try appendU16(&buf, self.allocator, grease_group);
        try appendU16(&buf, self.allocator, 1);
        try buf.append(self.allocator, 0x00);

        try appendU16(&buf, self.allocator, 0x001d);
        try appendU16(&buf, self.allocator, 32);
        var pub_x25519: [32]u8 = undefined;
        std.crypto.random.bytes(&pub_x25519);
        try buf.appendSlice(self.allocator, &pub_x25519);

        try appendU16(&buf, self.allocator, 0x002d);
        try appendU16(&buf, self.allocator, 2);
        try buf.append(self.allocator, 1);
        try buf.append(self.allocator, 0x01);

        try appendU16(&buf, self.allocator, 0x002b);
        try appendU16(&buf, self.allocator, 7);
        try buf.append(self.allocator, 6);
        try appendU16(&buf, self.allocator, grease_version);
        try appendU16(&buf, self.allocator, 0x0304);
        try appendU16(&buf, self.allocator, 0x0303);

        try appendU16(&buf, self.allocator, 0x001b);
        try appendU16(&buf, self.allocator, 3);
        try buf.append(self.allocator, 2);
        try appendU16(&buf, self.allocator, 0x0002);

        try appendU16(&buf, self.allocator, grease_ext);
        try appendU16(&buf, self.allocator, 1);
        try buf.append(self.allocator, 0x00);

        const current_total = buf.items.len;
        const target_size: usize = 517;
        if (current_total + 4 < target_size) {
            const pad_len = target_size - (current_total + 4);
            try appendU16(&buf, self.allocator, 0x0015);
            try appendU16(&buf, self.allocator, @intCast(pad_len));
            for (0..pad_len) |_| try buf.append(self.allocator, 0x00);
        }

        const total_ext_len: u16 = @intCast(buf.items.len - ext_start);
        buf.items[ext_len_offset] = @intCast((total_ext_len >> 8) & 0xff);
        buf.items[ext_len_offset + 1] = @intCast(total_ext_len & 0xff);

        const hs_len: u32 = @intCast(buf.items.len - (hs_start + 4));
        buf.items[hs_start + 1] = @intCast((hs_len >> 16) & 0xff);
        buf.items[hs_start + 2] = @intCast((hs_len >> 8) & 0xff);
        buf.items[hs_start + 3] = @intCast(hs_len & 0xff);

        const record_len: u16 = @intCast(buf.items.len - 5);
        buf.items[3] = @intCast((record_len >> 8) & 0xff);
        buf.items[4] = @intCast(record_len & 0xff);

        return try buf.toOwnedSlice(self.allocator);
    }

    fn appendU16(buf: *std.ArrayList(u8), allocator: std.mem.Allocator, val: u16) !void {
        try buf.append(allocator, @intCast((val >> 8) & 0xff));
        try buf.append(allocator, @intCast(val & 0xff));
    }
};
