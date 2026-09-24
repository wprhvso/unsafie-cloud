const std = @import("std");

pub const embedded_rules_bin = @embedFile("rules.bin");

pub const RulesEngine = struct {
    data: []const u8,
    ipv4_off: u32,
    ipv4_count: u32,
    suf_table: u32,
    suf_count: u32,
    suf_blob: u32,
    suf_blob_len: u32,
    exc_table: u32,
    exc_count: u32,
    exc_blob: u32,
    exc_blob_len: u32,
    kw_table: u32,
    kw_count: u32,
    kw_blob: u32,
    kw_blob_len: u32,

    pub fn init(allocator: std.mem.Allocator) RulesEngine {
        _ = allocator;
        return fromSlice(embedded_rules_bin) catch initFallback();
    }

    pub fn fromSlice(data: []const u8) !RulesEngine {
        if (data.len < 128) return error.TooSmall;
        if (!std.mem.eql(u8, data[0..8], "DUMBRULE")) return error.InvalidMagic;

        return RulesEngine{
            .data = data,
            .ipv4_off = std.mem.readInt(u32, data[52..56][0..4], .little),
            .ipv4_count = std.mem.readInt(u32, data[56..60][0..4], .little),
            .suf_table = std.mem.readInt(u32, data[68..72][0..4], .little),
            .suf_count = std.mem.readInt(u32, data[72..76][0..4], .little),
            .suf_blob = std.mem.readInt(u32, data[76..80][0..4], .little),
            .suf_blob_len = std.mem.readInt(u32, data[80..84][0..4], .little),
            .exc_table = std.mem.readInt(u32, data[84..88][0..4], .little),
            .exc_count = std.mem.readInt(u32, data[88..92][0..4], .little),
            .exc_blob = std.mem.readInt(u32, data[92..96][0..4], .little),
            .exc_blob_len = std.mem.readInt(u32, data[96..100][0..4], .little),
            .kw_table = std.mem.readInt(u32, data[100..104][0..4], .little),
            .kw_count = std.mem.readInt(u32, data[104..108][0..4], .little),
            .kw_blob = std.mem.readInt(u32, data[108..112][0..4], .little),
            .kw_blob_len = std.mem.readInt(u32, data[112..116][0..4], .little),
        };
    }

    fn initFallback() RulesEngine {
        return RulesEngine{
            .data = &[_]u8{},
            .ipv4_off = 0,
            .ipv4_count = 0,
            .suf_table = 0,
            .suf_count = 0,
            .suf_blob = 0,
            .suf_blob_len = 0,
            .exc_table = 0,
            .exc_count = 0,
            .exc_blob = 0,
            .exc_blob_len = 0,
            .kw_table = 0,
            .kw_count = 0,
            .kw_blob = 0,
            .kw_blob_len = 0,
        };
    }

    pub fn isDomesticIp(self: *const RulesEngine, ip: u32) bool {
        if (self.ipv4_count == 0 or self.data.len == 0) {
            const b0: u8 = @intCast((ip >> 24) & 0xff);
            const b1: u8 = @intCast((ip >> 16) & 0xff);
            if (b0 == 5 and b1 >= 8) return true;
            if (b0 == 77 and b1 >= 88 and b1 <= 95) return true;
            if (b0 == 178 and (b1 >= 236 or b1 == 248)) return true;
            if (b0 == 213 and b1 >= 180) return true;
            if (b0 == 87 and b1 >= 240) return true;
            return false;
        }

        var lo: usize = 0;
        var hi: usize = self.ipv4_count;

        while (lo < hi) {
            const mid = lo + (hi - lo) / 2;
            const offset = self.ipv4_off + mid * 8;
            if (offset + 8 > self.data.len) return false;
            const start = std.mem.readInt(u32, self.data[offset .. offset + 4][0..4], .little);
            if (start <= ip) {
                lo = mid + 1;
            } else {
                hi = mid;
            }
        }

        if (lo == 0) return false;
        const rec_offset = self.ipv4_off + (lo - 1) * 8;
        if (rec_offset + 8 > self.data.len) return false;
        const end = std.mem.readInt(u32, self.data[rec_offset + 4 .. rec_offset + 8][0..4], .little);
        return ip <= end;
    }

    pub fn isDomesticDomain(self: *const RulesEngine, domain: []const u8) bool {
        var clean = domain;
        while (clean.len > 0 and clean[clean.len - 1] == '.') {
            clean = clean[0 .. clean.len - 1];
        }
        while (clean.len > 0 and clean[0] == '.') {
            clean = clean[1..];
        }
        if (clean.len == 0) return false;

        var lower_buf: [256]u8 = undefined;
        const norm = if (clean.len <= lower_buf.len) blk: {
            for (clean, 0..) |c, i| {
                lower_buf[i] = std.ascii.toLower(c);
            }
            break :blk lower_buf[0..clean.len];
        } else clean;

        if (self.exc_count > 0 and self.searchTable(self.exc_table, self.exc_count, self.exc_blob, self.exc_blob_len, norm)) {
            return true;
        }

        if (self.suf_count > 0) {
            var i: usize = 0;
            while (true) {
                if (self.searchTable(self.suf_table, self.suf_count, self.suf_blob, self.suf_blob_len, norm[i..])) {
                    return true;
                }
                const dot_pos = std.mem.indexOfScalarPos(u8, norm, i, '.');
                if (dot_pos) |pos| {
                    i = pos + 1;
                    if (i >= norm.len) break;
                } else {
                    break;
                }
            }
        }

        if (self.kw_count > 0) {
            var k: usize = 0;
            while (k < self.kw_count) : (k += 1) {
                if (self.getStringAt(self.kw_table, self.kw_blob, self.kw_blob_len, k)) |kw| {
                    if (kw.len > 0 and std.mem.indexOf(u8, norm, kw) != null) {
                        return true;
                    }
                }
            }
        }

        const fallback_suffixes = [_][]const u8{
            ".ru",
            ".su",
            ".рф",
            "yandex.ru",
            "vk.com",
            "gosuslugi.ru",
            "sberbank.ru",
            "mail.ru",
            "tinkoff.ru",
            "t-bank.ru",
            "kinopoisk.ru",
            "dzen.ru",
            "ozon.ru",
            "wildberries.ru",
            "avito.ru",
        };

        for (fallback_suffixes) |suf| {
            if (std.mem.endsWith(u8, norm, suf)) return true;
        }

        return false;
    }

    fn searchTable(self: *const RulesEngine, tbl_off: u32, count: u32, blob_off: u32, blob_len: u32, key: []const u8) bool {
        if (count == 0) return false;
        var lo: usize = 0;
        var hi: usize = count;

        while (lo < hi) {
            const mid = lo + (hi - lo) / 2;
            const str = self.getStringAt(tbl_off, blob_off, blob_len, mid) orelse return false;
            if (std.mem.order(u8, str, key) == .lt) {
                lo = mid + 1;
            } else {
                hi = mid;
            }
        }

        if (lo < count) {
            const found = self.getStringAt(tbl_off, blob_off, blob_len, lo) orelse return false;
            return std.mem.eql(u8, found, key);
        }
        return false;
    }

    fn getStringAt(self: *const RulesEngine, tbl_off: u32, blob_off: u32, blob_len: u32, index: usize) ?[]const u8 {
        const off1_pos = tbl_off + index * 4;
        const off2_pos = tbl_off + (index + 1) * 4;
        if (off2_pos + 4 > self.data.len) return null;

        const o1 = std.mem.readInt(u32, self.data[off1_pos .. off1_pos + 4][0..4], .little);
        const o2 = std.mem.readInt(u32, self.data[off2_pos .. off2_pos + 4][0..4], .little);

        if (o1 <= o2 and o2 <= blob_len) {
            const abs_start = blob_off + o1;
            const abs_end = blob_off + o2;
            if (abs_end <= self.data.len) {
                return self.data[abs_start..abs_end];
            }
        }
        return null;
    }
};

test "rules engine domestic lookup" {
    const engine = RulesEngine.init(std.testing.allocator);
    try std.testing.expect(engine.isDomesticDomain("yandex.ru"));
    try std.testing.expect(engine.isDomesticDomain("sub.gosuslugi.ru"));
    try std.testing.expect(engine.isDomesticDomain("test.ru"));
    try std.testing.expect(!engine.isDomesticDomain("google.com"));
    try std.testing.expect(!engine.isDomesticDomain("netflix.com"));
}
