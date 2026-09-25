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

    pub fn initDefault() RulesEngine {
        return fromSlice(embedded_rules_bin) catch fallback();
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

    fn fallback() RulesEngine {
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

    pub fn matchIp(self: *const RulesEngine, ip: u32) bool {
        if (self.ipv4_count == 0) return false;
        var lo: usize = 0;
        var hi: usize = self.ipv4_count;

        while (lo < hi) {
            const mid = lo + (hi - lo) / 2;
            const rec_pos = self.ipv4_off + mid * 8;
            if (rec_pos + 4 > self.data.len) return false;
            const start = std.mem.readInt(u32, self.data[rec_pos .. rec_pos + 4][0..4], .little);
            if (start <= ip) {
                lo = mid + 1;
            } else {
                hi = mid;
            }
        }

        if (lo == 0) return false;
        const target_rec = self.ipv4_off + (lo - 1) * 8;
        if (target_rec + 8 > self.data.len) return false;
        const end = std.mem.readInt(u32, self.data[target_rec + 4 .. target_rec + 8][0..4], .little);
        return ip <= end;
    }

    pub fn matchDomain(self: *const RulesEngine, domain: []const u8) bool {
        if (self.data.len == 0) return false;

        if (self.exc_count > 0 and self.searchTable(self.exc_table, self.exc_blob, self.exc_count, domain)) {
            return true;
        }

        if (self.suf_count > 0) {
            var i: usize = 0;
            while (i < domain.len) {
                if (self.searchTable(self.suf_table, self.suf_blob, self.suf_count, domain[i..])) {
                    return true;
                }
                if (std.mem.indexOfScalarPos(u8, domain, i, '.')) |dot| {
                    i = dot + 1;
                } else {
                    break;
                }
            }
        }

        if (self.kw_count > 0) {
            var k: usize = 0;
            while (k < self.kw_count) : (k += 1) {
                const kw = self.getStringAt(self.kw_table, self.kw_blob, k);
                if (kw.len > 0 and std.mem.indexOf(u8, domain, kw) != null) {
                    return true;
                }
            }
        }

        return false;
    }

    fn searchTable(self: *const RulesEngine, tbl_off: u32, blob_off: u32, count: u32, key: []const u8) bool {
        var lo: usize = 0;
        var hi: usize = count;

        while (lo < hi) {
            const mid = lo + (hi - lo) / 2;
            const item = self.getStringAt(tbl_off, blob_off, mid);
            if (std.mem.order(u8, item, key) == .lt) {
                lo = mid + 1;
            } else {
                hi = mid;
            }
        }

        if (lo < count) {
            const item = self.getStringAt(tbl_off, blob_off, lo);
            return std.mem.eql(u8, item, key);
        }
        return false;
    }

    fn getStringAt(self: *const RulesEngine, tbl_off: u32, blob_off: u32, idx: usize) []const u8 {
        const off_pos = tbl_off + idx * 4;
        if (off_pos + 8 > self.data.len) return "";
        const lo = std.mem.readInt(u32, self.data[off_pos .. off_pos + 4][0..4], .little);
        const hi = std.mem.readInt(u32, self.data[off_pos + 4 .. off_pos + 8][0..4], .little);
        if (lo >= hi) return "";
        const str_start = blob_off + lo;
        const str_end = blob_off + hi;
        if (str_end > self.data.len) return "";
        return self.data[str_start..str_end];
    }
};
