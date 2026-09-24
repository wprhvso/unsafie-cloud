const std = @import("std");

pub const LearnerSet = struct {
    allocator: std.mem.Allocator,
    mutex: std.Thread.RwLock = .{},
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
        const expires = std.time.timestamp() + self.ttl_seconds;
        try self.seen.put(ip, expires);
    }

    pub fn has(self: *LearnerSet, ip: u32) bool {
        self.mutex.lockShared();
        defer self.mutex.unlockShared();
        const expires = self.seen.get(ip) orelse return false;
        return std.time.timestamp() < expires;
    }

    pub fn sweep(self: *LearnerSet) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        const now = std.time.timestamp();
        var to_remove = std.ArrayList(u32){};
        defer to_remove.deinit(self.allocator);

        var it = self.seen.iterator();
        while (it.next()) |entry| {
            if (now >= entry.value_ptr.*) {
                to_remove.append(self.allocator, entry.key_ptr.*) catch break;
            }
        }

        for (to_remove.items) |k| {
            _ = self.seen.remove(k);
        }
    }
};

test "learner set lifecycle" {
    var ls = LearnerSet.init(std.testing.allocator);
    defer ls.deinit();

    try ls.learn(0x01020304);
    try std.testing.expect(ls.has(0x01020304));
    try std.testing.expect(!ls.has(0x05060708));
}
