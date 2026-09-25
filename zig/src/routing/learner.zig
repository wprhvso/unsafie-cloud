const std = @import("std");
const sys = @import("../sys.zig");

pub const SpinLock = struct {
    state: std.atomic.Value(bool) = std.atomic.Value(bool).init(false),

    pub fn lock(self: *SpinLock) void {
        while (self.state.swap(true, .acquire)) {
            std.atomic.spinLoopHint();
        }
    }

    pub fn unlock(self: *SpinLock) void {
        self.state.store(false, .release);
    }
};

pub const LearnerSet = struct {
    allocator: std.mem.Allocator,
    mutex: SpinLock = .{},
    seen: std.AutoHashMap(u32, i64),
    ttl_seconds: i64 = 1800,

    pub fn init(allocator: std.mem.Allocator) LearnerSet {
        return .{
            .allocator = allocator,
            .seen = std.AutoHashMap(u32, i64).init(allocator),
            .ttl_seconds = 1800,
        };
    }

    pub fn deinit(self: *LearnerSet) void {
        self.seen.deinit();
    }

    pub fn learn(self: *LearnerSet, ip: u32) !void {
        self.mutex.lock();
        defer self.mutex.unlock();
        const expires = sys.timestamp() + self.ttl_seconds;
        try self.seen.put(ip, expires);
    }

    pub fn has(self: *LearnerSet, ip: u32) bool {
        self.mutex.lock();
        defer self.mutex.unlock();
        const expires = self.seen.get(ip) orelse return false;
        return sys.timestamp() < expires;
    }

    pub fn sweep(self: *LearnerSet) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        const now = sys.timestamp();
        var to_remove: std.ArrayList(u32) = .empty;
        defer to_remove.deinit(self.allocator);

        var it = self.seen.iterator();
        while (it.next()) |entry| {
            if (now >= entry.value_ptr.*) {
                to_remove.append(self.allocator, entry.key_ptr.*) catch {};
            }
        }
        for (to_remove.items) |ip| {
            _ = self.seen.remove(ip);
        }
    }
};
