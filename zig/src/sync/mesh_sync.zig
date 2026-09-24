const std = @import("std");
const config_mod = @import("../config.zig");
const protocol_mod = @import("../amnezia/protocol.zig");
const peer_mod = @import("../amnezia/peer.zig");
const crypto_mod = @import("../amnezia/crypto.zig");

pub const SyncManager = struct {
    allocator: std.mem.Allocator,
    config_file_path: ?[]const u8,

    pub fn init(allocator: std.mem.Allocator, config_path: ?[]const u8) SyncManager {
        return .{
            .allocator = allocator,
            .config_file_path = config_path,
        };
    }

    pub fn handleSyncMessage(
        self: *SyncManager,
        current_config: *config_mod.FullConfig,
        packet: []const u8,
        sender_peer: ?*peer_mod.PeerSession,
    ) !bool {
        if (packet.len < 64) return false;

        const magic = std.mem.readInt(u32, packet[0..4], .little);
        if (magic != protocol_mod.SYNC_MAGIC) return false;

        const new_timestamp = std.mem.readInt(i64, packet[4..12], .little);
        var sender_pubkey: [32]u8 = undefined;
        @memcpy(&sender_pubkey, packet[12..44]);

        const yaml_len = std.mem.readInt(u32, packet[60..64], .little);
        if (packet.len < 64 + yaml_len) return false;

        const is_authorized = blk: {
            if (sender_peer) |sp| {
                if (sp.can_sync_config or current_config.hasPermission(sp.role, "sync_config")) {
                    break :blk true;
                }
            }
            break :blk current_config.isPeerAuthorizedToSync(&sender_pubkey);
        };

        if (!is_authorized) return false;

        if (new_timestamp <= current_config.metadata.timestamp) return false;

        const yaml_payload = packet[64 .. 64 + yaml_len];
        var new_cfg = config_mod.parseYaml(self.allocator, yaml_payload) catch return false;

        if (self.config_file_path) |path| {
            new_cfg.saveToFile(path) catch {};
        }

        current_config.deinit();
        current_config.* = new_cfg;

        return true;
    }

    pub fn createSyncPacket(
        self: *SyncManager,
        out: []u8,
        config: *const config_mod.FullConfig,
        local_pubkey: [32]u8,
    ) !usize {
        _ = self;
        var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        defer arena.deinit();
        const a = arena.allocator();

        var list = std.ArrayList(u8){};
        defer list.deinit(a);
        try config.serialize(list.writer(a));

        var mac: [16]u8 = undefined;
        crypto_mod.computeMac(&mac, list.items, config.amnezia.psk);

        return protocol_mod.buildSyncPacket(out, config.metadata.timestamp, local_pubkey, mac, list.items);
    }
};
