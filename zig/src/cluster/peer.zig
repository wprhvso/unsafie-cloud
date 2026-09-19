const std = @import("std");

pub const PeerNode = struct {
    name: []const u8,
    ip_address: []const u8,
    is_active: bool = true,
};

pub const ClusterPeers = struct {
    peers: std.ArrayList(PeerNode),

    pub fn init(allocator: std.mem.Allocator) ClusterPeers {
        return .{
            .peers = std.ArrayList(PeerNode).init(allocator),
        };
    }

    pub fn deinit(self: *ClusterPeers) void {
        self.peers.deinit();
    }

    pub fn addPeer(self: *ClusterPeers, name: []const u8, ip_address: []const u8) !void {
        try self.peers.append(.{
            .name = name,
            .ip_address = ip_address,
        });
    }
};
