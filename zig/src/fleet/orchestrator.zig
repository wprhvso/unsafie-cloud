const std = @import("std");
const pool_state = @import("pool_state.zig");
const claim_engine = @import("claim_engine.zig");
const crypto = @import("crypto.zig");

pub const FleetOrchestrator = struct {
    allocator: std.mem.Allocator,
    pool: pool_state.GhPoolState,
    claims: claim_engine.ClaimEngine,
    master_key: [32]u8,
    node_id: u16,

    pub fn init(allocator: std.mem.Allocator, node_id: u16, master_key: [32]u8) FleetOrchestrator {
        return .{
            .allocator = allocator,
            .pool = pool_state.GhPoolState.init(allocator),
            .claims = claim_engine.ClaimEngine.init(allocator),
            .master_key = master_key,
            .node_id = node_id,
        };
    }

    pub fn deinit(self: *FleetOrchestrator) void {
        self.pool.deinit();
        self.claims.deinit();
    }

    pub fn addAccountToken(self: *FleetOrchestrator, slug: []const u8, raw_token: []const u8, concurrency: u32) !void {
        const encrypted = try crypto.FleetCrypto.encryptToken(self.allocator, self.master_key, raw_token);
        defer self.allocator.free(encrypted);
        try self.pool.addAccount(slug, encrypted, concurrency);
    }

    pub fn dispatchEphemeralRunner(self: *FleetOrchestrator, lease_id: []const u8) !?[]const u8 {
        const acc = self.pool.acquireAccount() orelse return null;

        const won = try self.claims.evaluateClaim(.{
            .slug = acc.slug,
            .node_id = self.node_id,
            .lease_id = lease_id,
            .timestamp = std.time.milliTimestamp(),
        });

        if (!won) {
            self.pool.releaseJob(acc.slug);
            return null;
        }

        return acc.slug;
    }

    pub fn getStatus(self: *FleetOrchestrator) ![]const u8 {
        var buf: [256]u8 = undefined;
        return std.fmt.bufPrint(&buf, "{{\"accounts_count\":{d},\"claims_count\":{d}}}", .{
            self.pool.accounts.count(),
            self.claims.active_claims.count(),
        });
    }
};
