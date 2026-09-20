const std = @import("std");

pub const RulesEngine = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) RulesEngine {
        return .{ .allocator = allocator };
    }

    pub fn isDomesticDomain(self: *const RulesEngine, domain: []const u8) bool {
        _ = self;
        const suffixes = [_][]const u8{
            ".ru",
            ".рф",
            ".su",
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

        for (suffixes) |suf| {
            if (std.mem.endsWith(u8, domain, suf)) return true;
        }
        return false;
    }

    pub fn isDomesticIp(self: *const RulesEngine, ip: u32) bool {
        _ = self;
        const b0: u8 = @intCast((ip >> 24) & 0xff);
        const b1: u8 = @intCast((ip >> 16) & 0xff);

        if (b0 == 5 and b1 >= 8 and b1 <= 255) return true;
        if (b0 == 77 and b1 >= 88 and b1 <= 95) return true;
        if (b0 == 178 and (b1 >= 236 or b1 == 248)) return true;
        if (b0 == 213 and b1 >= 180) return true;
        if (b0 == 87 and b1 >= 240) return true;

        return false;
    }
};
