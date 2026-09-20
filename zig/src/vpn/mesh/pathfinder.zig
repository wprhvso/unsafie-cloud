const std = @import("std");
const telemetry = @import("telemetry.zig");

pub const RoutePath = struct {
    next_hop: u16,
    exit_node: u16,
    total_cost: u32,
    is_direct: bool,
};

pub const Pathfinder = struct {
    allocator: std.mem.Allocator,
    telem: *telemetry.MeshTelemetry,
    foreign_nodes: std.ArrayList(u16),
    domestic_nodes: std.ArrayList(u16),

    pub fn init(allocator: std.mem.Allocator, telem: *telemetry.MeshTelemetry) Pathfinder {
        var pf = Pathfinder{
            .allocator = allocator,
            .telem = telem,
            .foreign_nodes = std.ArrayList(u16){},
            .domestic_nodes = std.ArrayList(u16){},
        };
        pf.foreign_nodes.append(allocator, 1) catch {};
        pf.foreign_nodes.append(allocator, 2) catch {};
        pf.domestic_nodes.append(allocator, 3) catch {};
        return pf;
    }

    pub fn deinit(self: *Pathfinder) void {
        self.foreign_nodes.deinit(self.allocator);
        self.domestic_nodes.deinit(self.allocator);
    }

    pub fn findBestRoute(self: *Pathfinder, my_node_id: u16) ?RoutePath {
        var min_cost: u32 = std.math.maxInt(u32);
        var best_route: ?RoutePath = null;

        for (self.foreign_nodes.items) |exit_id| {
            const direct_cost = self.telem.getLinkCost(exit_id);
            var best_hop_cost: u32 = direct_cost;
            var best_next_hop: u16 = exit_id;

            for (self.domestic_nodes.items) |bridge_id| {
                if (bridge_id == my_node_id) continue;
                const cost_to_bridge = self.telem.getLinkCost(bridge_id);
                const bridge_cost_total = if (cost_to_bridge < std.math.maxInt(u32) / 2)
                    cost_to_bridge + 40 + 10
                else
                    std.math.maxInt(u32);

                if (bridge_cost_total < best_hop_cost) {
                    best_hop_cost = bridge_cost_total;
                    best_next_hop = bridge_id;
                }
            }

            if (best_hop_cost < min_cost) {
                min_cost = best_hop_cost;
                best_route = .{
                    .next_hop = best_next_hop,
                    .exit_node = exit_id,
                    .total_cost = best_hop_cost,
                    .is_direct = (best_next_hop == exit_id),
                };
            }
        }

        return best_route;
    }
};
