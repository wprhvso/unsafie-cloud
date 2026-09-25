const std = @import("std");
const protocol_mod = @import("protocol.zig");
const sys = @import("../sys.zig");

pub const PeerSession = struct {
    name: []const u8 = "",
    role: []const u8 = "client",
    public_key: [32]u8 = @as([32]u8, @splat(0)),
    endpoint: ?protocol_mod.SocketAddress = null,
    allowed_ip: u32 = 0,
    allowed_mask: u32 = 0xffffffff,
    can_sync_config: bool = false,
    persistent_keepalive: u32 = 25,

    last_seen_ts: std.atomic.Value(i64) = std.atomic.Value(i64).init(0),
    tx_bytes: std.atomic.Value(u64) = std.atomic.Value(u64).init(0),
    rx_bytes: std.atomic.Value(u64) = std.atomic.Value(u64).init(0),
    sender_index: u32 = 0,
    receiver_index: u32 = 0,
    tx_counter: std.atomic.Value(u64) = std.atomic.Value(u64).init(0),
    rx_counter: std.atomic.Value(u64) = std.atomic.Value(u64).init(0),
    session_key: [32]u8 = @as([32]u8, @splat(0)),
    has_session: std.atomic.Value(bool) = std.atomic.Value(bool).init(false),

    pub fn matchesIp(self: *const PeerSession, ip: u32) bool {
        return (ip & self.allowed_mask) == (self.allowed_ip & self.allowed_mask);
    }

    pub fn recordTx(self: *PeerSession, bytes: usize) void {
        _ = self.tx_bytes.fetchAdd(@intCast(bytes), .monotonic);
    }

    pub fn recordRx(self: *PeerSession, bytes: usize) void {
        _ = self.rx_bytes.fetchAdd(@intCast(bytes), .monotonic);
        self.last_seen_ts.store(sys.timestamp(), .monotonic);
    }
};
