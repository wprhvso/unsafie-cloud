const std = @import("std");

pub const Endpoint = struct {
    ip: u32,
    port: u16,
};

pub const HolePunchCoordinator = struct {
    allocator: std.mem.Allocator,
    endpoints: std.AutoHashMap(u16, Endpoint),

    pub fn init(allocator: std.mem.Allocator) HolePunchCoordinator {
        return .{
            .allocator = allocator,
            .endpoints = std.AutoHashMap(u16, Endpoint).init(allocator),
        };
    }

    pub fn deinit(self: *HolePunchCoordinator) void {
        self.endpoints.deinit();
    }

    pub fn registerEndpoint(self: *HolePunchCoordinator, node_id: u16, ip: u32, port: u16) !void {
        try self.endpoints.put(node_id, .{ .ip = ip, .port = port });
    }

    pub fn getPeerEndpoint(self: *HolePunchCoordinator, node_id: u16) ?Endpoint {
        return self.endpoints.get(node_id);
    }

    pub fn buildProbePacket(my_node_id: u16, out: []u8) usize {
        if (out.len < 8) return 0;
        out[0] = 0x55;
        out[1] = 0x4e;
        out[2] = 0x50;
        out[3] = 0x32;
        out[4] = 0x50;
        out[5] = 0x01;
        out[6] = @intCast((my_node_id >> 8) & 0xff);
        out[7] = @intCast(my_node_id & 0xff);
        return 8;
    }
};
