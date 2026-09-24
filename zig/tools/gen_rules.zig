const std = @import("std");

pub const Magic = "DUMBRULE";
pub const Version: u32 = 1;
pub const HeaderSize: usize = 128;

pub const Ipv4Range = struct {
    start: u32,
    end: u32,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();

    _ = args.skip();
    var out_path: []const u8 = "src/vpn/rules.bin";
    var seed_path: ?[]const u8 = null;

    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "-o") or std.mem.eql(u8, arg, "--out")) {
            if (args.next()) |val| {
                out_path = val;
            }
        } else if (std.mem.eql(u8, arg, "--seed")) {
            if (args.next()) |val| {
                seed_path = val;
            }
        }
    }

    var ipv4_ranges = std.ArrayList(Ipv4Range){};
    defer ipv4_ranges.deinit(allocator);

    var suffixes = std.ArrayList([]const u8){};
    defer {
        for (suffixes.items) |s| allocator.free(s);
        suffixes.deinit(allocator);
    }

    var exacts = std.ArrayList([]const u8){};
    defer {
        for (exacts.items) |s| allocator.free(s);
        exacts.deinit(allocator);
    }

    var keywords = std.ArrayList([]const u8){};
    defer {
        for (keywords.items) |s| allocator.free(s);
        keywords.deinit(allocator);
    }

    var seed_loaded = false;
    if (seed_path) |sp| {
        if (std.fs.cwd().openFile(sp, .{})) |file| {
            defer file.close();
            const stat = try file.stat();
            if (stat.size >= HeaderSize) {
                const data = try file.readToEndAlloc(allocator, @intCast(stat.size));
                defer allocator.free(data);
                if (std.mem.eql(u8, data[0..8], Magic)) {
                    try parseExistingRules(allocator, data, &ipv4_ranges, &suffixes, &exacts, &keywords);
                    seed_loaded = true;
                }
            }
        } else |_| {}
    }

    if (!seed_loaded) {
        try populateDefaultRules(allocator, &ipv4_ranges, &suffixes, &exacts);
    }

    try sortAndDedup(allocator, &ipv4_ranges, &suffixes, &exacts, &keywords);
    try writeRulesBin(allocator, out_path, ipv4_ranges.items, suffixes.items, exacts.items, keywords.items);
}

fn parseExistingRules(
    allocator: std.mem.Allocator,
    data: []const u8,
    ipv4_list: *std.ArrayList(Ipv4Range),
    suffixes: *std.ArrayList([]const u8),
    exacts: *std.ArrayList([]const u8),
    keywords: *std.ArrayList([]const u8),
) !void {
    const ipv4_off = std.mem.readInt(u32, data[52..56][0..4], .little);
    const ipv4_cnt = std.mem.readInt(u32, data[56..60][0..4], .little);

    var i: usize = 0;
    while (i < ipv4_cnt) : (i += 1) {
        const offset = ipv4_off + i * 8;
        if (offset + 8 <= data.len) {
            const start = std.mem.readInt(u32, data[offset .. offset + 4][0..4], .little);
            const end = std.mem.readInt(u32, data[offset + 4 .. offset + 8][0..4], .little);
            try ipv4_list.append(allocator, .{ .start = start, .end = end });
        }
    }

    try readStrTable(allocator, data, 68, 72, 76, 80, suffixes);
    try readStrTable(allocator, data, 84, 88, 92, 96, exacts);
    try readStrTable(allocator, data, 100, 104, 108, 112, keywords);
}

fn readStrTable(
    allocator: std.mem.Allocator,
    data: []const u8,
    table_off_pos: usize,
    count_pos: usize,
    blob_off_pos: usize,
    blob_len_pos: usize,
    out: *std.ArrayList([]const u8),
) !void {
    const tbl_off = std.mem.readInt(u32, data[table_off_pos .. table_off_pos + 4][0..4], .little);
    const count = std.mem.readInt(u32, data[count_pos .. count_pos + 4][0..4], .little);
    const blob_off = std.mem.readInt(u32, data[blob_off_pos .. blob_off_pos + 4][0..4], .little);
    const blob_len = std.mem.readInt(u32, data[blob_len_pos .. blob_len_pos + 4][0..4], .little);

    if (tbl_off + (count + 1) * 4 > data.len or blob_off + blob_len > data.len) return;

    const blob = data[blob_off .. blob_off + blob_len];
    var i: usize = 0;
    while (i < count) : (i += 1) {
        const o1 = std.mem.readInt(u32, data[tbl_off + i * 4 .. tbl_off + (i + 1) * 4][0..4], .little);
        const o2 = std.mem.readInt(u32, data[tbl_off + (i + 1) * 4 .. tbl_off + (i + 2) * 4][0..4], .little);
        if (o1 <= o2 and o2 <= blob.len) {
            const str = try allocator.dupe(u8, blob[o1..o2]);
            try out.append(allocator, str);
        }
    }
}

fn populateDefaultRules(
    allocator: std.mem.Allocator,
    ipv4_list: *std.ArrayList(Ipv4Range),
    suffixes: *std.ArrayList([]const u8),
    exacts: *std.ArrayList([]const u8),
) !void {
    const default_suffixes = [_][]const u8{
        "ru",
        "su",
        "by",
        "kz",
        "uz",
        "am",
        "kg",
        "tj",
        "az",
        "md",
        "moscow",
        "tatar",
        "xn--p1ai",
        "xn--p1acf",
        "xn--90ais",
        "xn--80ao21a",
        "xn--80adxhks",
        "xn--80asehdb",
        "xn--80aswg",
        "xn--d1acj3b",
        "yandex.ru",
        "ya.ru",
        "yandex.net",
        "yastatic.net",
        "vk.com",
        "vk.ru",
        "userapi.com",
        "vkuser.net",
        "mail.ru",
        "rambler.ru",
        "gosuslugi.ru",
        "nalog.ru",
        "nalog.gov.ru",
        "mos.ru",
        "emias.info",
        "sberbank.ru",
        "sber.ru",
        "sberbank.com",
        "tinkoff.ru",
        "t-bank.ru",
        "vtb.ru",
        "alfabank.ru",
        "rshb.ru",
        "gazprombank.ru",
        "raiffeisen.ru",
        "ozon.ru",
        "ozonusercontent.com",
        "wildberries.ru",
        "wb.ru",
        "avito.ru",
        "kinopoisk.ru",
        "dzen.ru",
        "rutube.ru",
        "hh.ru",
        "cian.ru",
        "2gis.ru",
        "kaspersky.ru",
        "habr.com",
        "pikabu.ru",
        "rbc.ru",
        "ria.ru",
        "tass.ru",
        "lenta.ru",
        "kommersant.ru",
    };

    for (default_suffixes) |s| {
        try suffixes.append(allocator, try allocator.dupe(u8, s));
    }

    const default_exacts = [_][]const u8{
        "yandex.com",
        "vkontakte.ru",
    };
    for (default_exacts) |e| {
        try exacts.append(allocator, try allocator.dupe(u8, e));
    }

    const default_ranges = [_][2]u32{
        .{ 0x05080000, 0x05ffffff },
        .{ 0x4d580000, 0x4d5fffff },
        .{ 0xb2ec0000, 0xb2ffffff },
        .{ 0xd5b40000, 0xd5ffffff },
        .{ 0x57f00000, 0x57ffffff },
        .{ 0x5fc80000, 0x5fcfffff },
        .{ 0x6e600000, 0x6e7fffff },
    };

    for (default_ranges) |r| {
        try ipv4_list.append(allocator, .{ .start = r[0], .end = r[1] });
    }
}

fn sortAndDedup(
    allocator: std.mem.Allocator,
    ipv4_list: *std.ArrayList(Ipv4Range),
    suffixes: *std.ArrayList([]const u8),
    exacts: *std.ArrayList([]const u8),
    keywords: *std.ArrayList([]const u8),
) !void {
    _ = allocator;
    std.mem.sort(Ipv4Range, ipv4_list.items, {}, struct {
        fn lessThan(_: void, a: Ipv4Range, b: Ipv4Range) bool {
            return a.start < b.start;
        }
    }.lessThan);

    if (ipv4_list.items.len > 1) {
        var write_idx: usize = 0;
        var read_idx: usize = 1;
        while (read_idx < ipv4_list.items.len) : (read_idx += 1) {
            if (ipv4_list.items[read_idx].start <= ipv4_list.items[write_idx].end + 1) {
                if (ipv4_list.items[read_idx].end > ipv4_list.items[write_idx].end) {
                    ipv4_list.items[write_idx].end = ipv4_list.items[read_idx].end;
                }
            } else {
                write_idx += 1;
                ipv4_list.items[write_idx] = ipv4_list.items[read_idx];
            }
        }
        ipv4_list.shrinkRetainingCapacity(write_idx + 1);
    }

    sortStrings(suffixes.items);
    dedupStrings(suffixes);

    sortStrings(exacts.items);
    dedupStrings(exacts);

    sortStrings(keywords.items);
    dedupStrings(keywords);
}

fn sortStrings(items: [][]const u8) void {
    std.mem.sort([]const u8, items, {}, struct {
        fn lessThan(_: void, a: []const u8, b: []const u8) bool {
            return std.mem.order(u8, a, b) == .lt;
        }
    }.lessThan);
}

fn dedupStrings(list: *std.ArrayList([]const u8)) void {
    if (list.items.len <= 1) return;
    var w: usize = 0;
    var r: usize = 1;
    while (r < list.items.len) : (r += 1) {
        if (!std.mem.eql(u8, list.items[w], list.items[r])) {
            w += 1;
            list.items[w] = list.items[r];
        }
    }
    list.shrinkRetainingCapacity(w + 1);
}

fn writeRulesBin(
    allocator: std.mem.Allocator,
    path: []const u8,
    ipv4_items: []const Ipv4Range,
    suf_items: []const []const u8,
    exc_items: []const []const u8,
    kw_items: []const []const u8,
) !void {
    var body = std.ArrayList(u8){};
    defer body.deinit(allocator);

    var header = [_]u8{0} ** HeaderSize;
    @memcpy(header[0..8], Magic);
    std.mem.writeInt(u32, header[8..12][0..4], Version, .little);
    const now: u64 = @intCast(std.time.timestamp());
    std.mem.writeInt(u64, header[12..20][0..8], now, .little);

    const ipv4_off: u32 = @intCast(HeaderSize + body.items.len);
    std.mem.writeInt(u32, header[52..56][0..4], ipv4_off, .little);
    std.mem.writeInt(u32, header[56..60][0..4], @intCast(ipv4_items.len), .little);

    for (ipv4_items) |r| {
        var rec: [8]u8 = undefined;
        std.mem.writeInt(u32, rec[0..4][0..4], r.start, .little);
        std.mem.writeInt(u32, rec[4..8][0..4], r.end, .little);
        try body.appendSlice(allocator, &rec);
    }

    std.mem.writeInt(u32, header[60..64][0..4], 0, .little);
    std.mem.writeInt(u32, header[64..68][0..4], 0, .little);

    try writeTableToBody(allocator, suf_items, &body, header[68..72][0..4], header[72..76][0..4], header[76..80][0..4], header[80..84][0..4]);
    try writeTableToBody(allocator, exc_items, &body, header[84..88][0..4], header[88..92][0..4], header[92..96][0..4], header[96..100][0..4]);
    try writeTableToBody(allocator, kw_items, &body, header[100..104][0..4], header[104..108][0..4], header[108..112][0..4], header[112..116][0..4]);

    var h = std.crypto.hash.Blake3.init(.{});
    h.update(&header);
    h.update(body.items);
    var hash_out: [32]u8 = undefined;
    h.final(&hash_out);
    @memcpy(header[20..52], &hash_out);

    if (std.fs.path.dirname(path)) |d| {
        try std.fs.cwd().makePath(d);
    }

    var file = try std.fs.cwd().createFile(path, .{});
    defer file.close();

    try file.writeAll(&header);
    try file.writeAll(body.items);
}

fn writeTableToBody(
    allocator: std.mem.Allocator,
    items: []const []const u8,
    body: *std.ArrayList(u8),
    tbl_off_slice: *[4]u8,
    count_slice: *[4]u8,
    blob_off_slice: *[4]u8,
    blob_len_slice: *[4]u8,
) !void {
    const tbl_off: u32 = @intCast(HeaderSize + body.items.len);
    std.mem.writeInt(u32, tbl_off_slice, tbl_off, .little);
    std.mem.writeInt(u32, count_slice, @intCast(items.len), .little);

    var offsets = std.ArrayList(u32){};
    defer offsets.deinit(allocator);

    var blob = std.ArrayList(u8){};
    defer blob.deinit(allocator);

    var pos: u32 = 0;
    for (items) |it| {
        try offsets.append(allocator, pos);
        try blob.appendSlice(allocator, it);
        pos += @intCast(it.len);
    }
    try offsets.append(allocator, pos);

    for (offsets.items) |o| {
        var buf: [4]u8 = undefined;
        std.mem.writeInt(u32, &buf, o, .little);
        try body.appendSlice(allocator, &buf);
    }

    const blob_off: u32 = @intCast(HeaderSize + body.items.len);
    std.mem.writeInt(u32, blob_off_slice, blob_off, .little);
    std.mem.writeInt(u32, blob_len_slice, @intCast(blob.items.len), .little);
    try body.appendSlice(allocator, blob.items);
}
