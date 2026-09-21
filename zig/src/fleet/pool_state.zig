const std = @import("std");

pub const GhAccount = struct {
    slug: []const u8,
    enc_token: []const u8,
    active_jobs: u32 = 0,
    concurrency_limit: u32 = 20,
    cooldown_until: i64 = 0,
};

pub const GhPoolState = struct {
    allocator: std.mem.Allocator,
    accounts: std.StringHashMap(GhAccount),

    pub fn init(allocator: std.mem.Allocator) GhPoolState {
        return .{
            .allocator = allocator,
            .accounts = std.StringHashMap(GhAccount).init(allocator),
        };
    }

    pub fn deinit(self: *GhPoolState) void {
        var it = self.accounts.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.value_ptr.slug);
            self.allocator.free(entry.value_ptr.enc_token);
        }
        self.accounts.deinit();
    }

    pub fn addAccount(self: *GhPoolState, slug: []const u8, enc_token: []const u8, concurrency: u32) !void {
        const slug_copy = try self.allocator.dupe(u8, slug);
        const token_copy = try self.allocator.dupe(u8, enc_token);

        try self.accounts.put(slug_copy, .{
            .slug = slug_copy,
            .enc_token = token_copy,
            .active_jobs = 0,
            .concurrency_limit = concurrency,
            .cooldown_until = 0,
        });
    }

    pub fn acquireAccount(self: *GhPoolState) ?*GhAccount {
        const now = std.time.timestamp();
        var best: ?*GhAccount = null;
        var min_load: u32 = std.math.maxInt(u32);

        var it = self.accounts.iterator();
        while (it.next()) |entry| {
            var acc = entry.value_ptr;
            if (acc.cooldown_until > now) continue;
            if (acc.active_jobs >= acc.concurrency_limit) continue;

            if (acc.active_jobs < min_load) {
                min_load = acc.active_jobs;
                best = acc;
            }
        }

        if (best) |b| {
            b.active_jobs += 1;
        }
        return best;
    }

    pub fn releaseJob(self: *GhPoolState, slug: []const u8) void {
        if (self.accounts.getPtr(slug)) |acc| {
            if (acc.active_jobs > 0) {
                acc.active_jobs -= 1;
            }
        }
    }

    pub fn setCooldown(self: *GhPoolState, slug: []const u8, until_ts: i64) void {
        if (self.accounts.getPtr(slug)) |acc| {
            acc.cooldown_until = until_ts;
        }
    }
};
