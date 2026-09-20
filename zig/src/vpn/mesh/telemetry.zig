const std = @import("std");

pub const PeerLinkStats = struct {
    peer_id: u16,
    rtt_ms: u32 = 20,
    loss_rate_percent: u32 = 0,
    jitter_ms: u32 = 1,
    is_alive: bool = true,

    pub fn calculateCost(self: PeerLinkStats) u32 {
        if (!self.is_alive) return std.math.maxInt(u32);
        return self.rtt_ms + (self.loss_rate_percent * 30) + self.jitter_ms;
    }
};

pub const MeshTelemetry = struct {
    allocator: std.mem.Allocator,
    stats: std.AutoHashMap(u16, PeerLinkStats),

    pub fn init(allocator: std.mem.Allocator) MeshTelemetry {
        return .{
            .allocator = allocator,
            .stats = std.AutoHashMap(u16, PeerLinkStats).init(allocator),
        };
    }

    pub fn deinit(self: *MeshTelemetry) void {
        self.stats.deinit();
    }

    pub fn recordPing(self: *MeshTelemetry, peer_id: u16, rtt_ms: u32, loss_pct: u32) !void {
        try self.stats.put(peer_id, .{
            .peer_id = peer_id,
            .rtt_ms = rtt_ms,
            .loss_rate_percent = loss_pct,
            .jitter_ms = 1,
            .is_alive = true,
        });
    }

    pub fn getLinkCost(self: *MeshTelemetry, peer_id: u16) u32 {
        if (self.stats.get(peer_id)) |s| {
            return s.calculateCost();
        }
        return std.math.maxInt(u32);
    }
};
