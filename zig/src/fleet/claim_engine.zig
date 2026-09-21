const std = @import("std");

pub const ClaimEvent = struct {
    slug: []const u8,
    node_id: u16,
    lease_id: []const u8,
    timestamp: i64,

    pub fn compare(a: ClaimEvent, b: ClaimEvent) std.math.Order {
        if (a.timestamp != b.timestamp) {
            return std.math.order(a.timestamp, b.timestamp);
        }
        return std.math.order(a.node_id, b.node_id);
    }
};

pub const ClaimEngine = struct {
    allocator: std.mem.Allocator,
    active_claims: std.StringHashMap(ClaimEvent),

    pub fn init(allocator: std.mem.Allocator) ClaimEngine {
        return .{
            .allocator = allocator,
            .active_claims = std.StringHashMap(ClaimEvent).init(allocator),
        };
    }

    pub fn deinit(self: *ClaimEngine) void {
        var it = self.active_claims.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.value_ptr.slug);
            self.allocator.free(entry.value_ptr.lease_id);
        }
        self.active_claims.deinit();
    }

    pub fn evaluateClaim(self: *ClaimEngine, incoming: ClaimEvent) !bool {
        if (self.active_claims.get(incoming.slug)) |existing| {
            if (ClaimEvent.compare(incoming, existing) == .lt) {
                _ = self.active_claims.remove(incoming.slug);
                const s = try self.allocator.dupe(u8, incoming.slug);
                const l = try self.allocator.dupe(u8, incoming.lease_id);
                try self.active_claims.put(s, .{
                    .slug = s,
                    .node_id = incoming.node_id,
                    .lease_id = l,
                    .timestamp = incoming.timestamp,
                });
                return true;
            }
            return false;
        } else {
            const s = try self.allocator.dupe(u8, incoming.slug);
            const l = try self.allocator.dupe(u8, incoming.lease_id);
            try self.active_claims.put(s, .{
                .slug = s,
                .node_id = incoming.node_id,
                .lease_id = l,
                .timestamp = incoming.timestamp,
            });
            return true;
        }
    }
};
