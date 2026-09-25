const std = @import("std");

pub const Ipv4Range = struct {
    start: u32,
    end: u32,
};

pub fn buildRulesBin(
    allocator: std.mem.Allocator,
    ipv4_ranges: []const Ipv4Range,
    suffixes: []const []const u8,
    exacts: []const []const u8,
    keywords: []const []const u8,
) ![]u8 {
    var body = std.ArrayList(u8){ .items = &.{}, .capacity = 0 };
    defer body.deinit(allocator);

    var header = [_]u8{0} ** 128;
    @memcpy(header[0..8], "DUMBRULE");
    std.mem.writeInt(u32, header[8..12][0..4], 1, .little);
    std.mem.writeInt(i64, header[12..20][0..8], std.time.timestamp(), .little);

    const ipv4_off: u32 = 128 + @as(u32, @intCast(body.items.len));
    std.mem.writeInt(u32, header[52..56][0..4], ipv4_off, .little);
    std.mem.writeInt(u32, header[56..60][0..4], @intCast(ipv4_ranges.len), .little);

    for (ipv4_ranges) |r| {
        var rec: [8]u8 = undefined;
        std.mem.writeInt(u32, rec[0..4], r.start, .little);
        std.mem.writeInt(u32, rec[4..8], r.end, .little);
        try body.appendSlice(allocator, &rec);
    }

    try writeStringTable(allocator, &header, &body, suffixes, 68, 72, 76, 80);
    try writeStringTable(allocator, &header, &body, exacts, 84, 88, 92, 96);
    try writeStringTable(allocator, &header, &body, keywords, 100, 104, 108, 112);

    var out = try allocator.alloc(u8, 128 + body.items.len);
    @memcpy(out[0..128], &header);
    @memcpy(out[128..], body.items);
    return out;
}

fn writeStringTable(
    allocator: std.mem.Allocator,
    header: *[128]u8,
    body: *std.ArrayList(u8),
    items: []const []const u8,
    tbl_off_hdr: usize,
    count_hdr: usize,
    blob_off_hdr: usize,
    blob_len_hdr: usize,
) !void {
    const tbl_off: u32 = 128 + @as(u32, @intCast(body.items.len));
    std.mem.writeInt(u32, header[tbl_off_hdr .. tbl_off_hdr + 4][0..4], tbl_off, .little);
    std.mem.writeInt(u32, header[count_hdr .. count_hdr + 4][0..4], @intCast(items.len), .little);

    var blob = std.ArrayList(u8){ .items = &.{}, .capacity = 0 };
    defer blob.deinit(allocator);

    var pos: u32 = 0;
    for (items) |it| {
        var off_bytes: [4]u8 = undefined;
        std.mem.writeInt(u32, &off_bytes, pos, .little);
        try body.appendSlice(allocator, &off_bytes);
        try blob.appendSlice(allocator, it);
        pos += @intCast(it.len);
    }
    var end_bytes: [4]u8 = undefined;
    std.mem.writeInt(u32, &end_bytes, pos, .little);
    try body.appendSlice(allocator, &end_bytes);

    const blob_off: u32 = 128 + @as(u32, @intCast(body.items.len));
    std.mem.writeInt(u32, header[blob_off_hdr .. blob_off_hdr + 4][0..4], blob_off, .little);
    std.mem.writeInt(u32, header[blob_len_hdr .. blob_len_hdr + 4][0..4], @intCast(blob.items.len), .little);
    try body.appendSlice(allocator, blob.items);
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();
    _ = args.skip();

    var out_path: []const u8 = "rules.bin";
    if (args.next()) |p| {
        out_path = p;
    }

    const default_suffixes = [_][]const u8{
        "auto.ru",
        "avito.ru",
        "dzen.ru",
        "gosuslugi.ru",
        "habr.com",
        "hh.ru",
        "kinopoisk.ru",
        "mail.ru",
        "mos.ru",
        "ozon.ru",
        "rambler.ru",
        "rbc.ru",
        "ru",
        "rutube.ru",
        "sber.ru",
        "su",
        "tbank.ru",
        "vk.com",
        "wildberries.ru",
        "yandex.ru",
        "рф",
    };

    const default_exacts = [_][]const u8{
        "an.yandex.ru",
        "api.vk.com",
        "sberbank.ru",
        "tinkoff.ru",
        "ya.ru",
    };

    const default_ranges = [_]Ipv4Range{
        .{ .start = 0x0a000000, .end = 0x0affffff },
        .{ .start = 0x4d580000, .end = 0x4d58ffff },
        .{ .start = 0x5f000000, .end = 0x5fffffff },
        .{ .start = 0xac100000, .end = 0xac1fffff },
        .{ .start = 0xc0a80000, .end = 0xc0a8ffff },
    };

    const bin_data = try buildRulesBin(
        allocator,
        &default_ranges,
        &default_suffixes,
        &default_exacts,
        &[_][]const u8{},
    );
    defer allocator.free(bin_data);

    const out_file = try std.fs.cwd().createFile(out_path, .{ .truncate = true });
    defer out_file.close();
    try out_file.writeAll(bin_data);
}
