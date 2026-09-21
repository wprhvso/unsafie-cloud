const std = @import("std");

pub const Magic: u32 = 0x55455654;

pub const EventCode = enum(u16) {
    node_registered = 0x0101,
    node_heartbeat = 0x0102,
    node_roamed = 0x0103,
    node_degraded = 0x0104,
    node_left = 0x0105,
    node_revoked = 0x0106,

    mesh_cost_updated = 0x0201,
    mesh_path_switched = 0x0202,
    mesh_stun_discovered = 0x0203,
    mesh_p2p_direct = 0x0204,
    mesh_relay_fallback = 0x0205,

    dns_query = 0x0301,
    dns_internal_resolved = 0x0302,
    dns_direct_learned = 0x0303,

    vm_defined = 0x0401,
    vm_started = 0x0402,
    vm_stopped = 0x0403,
    vm_baked = 0x0405,

    token_minted = 0x0501,
    grant_added = 0x0503,
    upgrade_swapped = 0x0602,
    _,

    pub fn name(self: EventCode) []const u8 {
        return switch (self) {
            .node_registered => "node.registered",
            .node_heartbeat => "node.heartbeat",
            .node_roamed => "node.roamed",
            .node_degraded => "node.degraded",
            .node_left => "node.left",
            .node_revoked => "node.revoked",
            .mesh_cost_updated => "mesh.cost_updated",
            .mesh_path_switched => "mesh.path_switched",
            .mesh_stun_discovered => "mesh.stun_discovered",
            .mesh_p2p_direct => "mesh.p2p_direct",
            .mesh_relay_fallback => "mesh.relay_fallback",
            .dns_query => "dns.query",
            .dns_internal_resolved => "dns.internal_resolved",
            .dns_direct_learned => "dns.direct_learned",
            .vm_defined => "vm.defined",
            .vm_started => "vm.started",
            .vm_stopped => "vm.stopped",
            .vm_baked => "vm.baked",
            .token_minted => "token.minted",
            .grant_added => "grant.added",
            .upgrade_swapped => "upgrade.swapped",
            _ => "unknown",
        };
    }
};

pub const EventHeader = extern struct {
    magic: u32 = Magic,
    node_id: u16,
    event_code: u16,
    seq: u64,
    ts: i64,
    payload_len: u32,
    flags: u16 = 0,
    reserved: u16 = 0,
    prev_hash: [32]u8,
    checksum: [32]u8,

    pub fn computeHash(
        node_id: u16,
        event_code: u16,
        seq: u64,
        ts: i64,
        payload_len: u32,
        prev_hash: [32]u8,
        payload: []const u8,
    ) [32]u8 {
        var hasher = std.crypto.hash.Blake3.init(.{});
        var meta_buf: [32]u8 = undefined;
        std.mem.writeInt(u16, meta_buf[0..2], node_id, .little);
        std.mem.writeInt(u16, meta_buf[2..4], event_code, .little);
        std.mem.writeInt(u64, meta_buf[4..12], seq, .little);
        std.mem.writeInt(i64, meta_buf[12..20], ts, .little);
        std.mem.writeInt(u32, meta_buf[20..24], payload_len, .little);
        hasher.update(meta_buf[0..24]);
        hasher.update(&prev_hash);
        hasher.update(payload);
        var out: [32]u8 = undefined;
        hasher.final(&out);
        return out;
    }
};

pub const EventRecord = struct {
    header: EventHeader,
    payload: []const u8,
};
