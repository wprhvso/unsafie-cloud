const std = @import("std");
const learner = @import("learner.zig");
const rules = @import("rules.zig");
const ipam = @import("ipam.zig");
const pathfinder = @import("mesh/pathfinder.zig");

pub const RouteAction = union(enum) {
    direct,
    mesh_internal: u16,
    tunnel_exit: u16,
    drop,
};

pub const Router = struct {
    allocator: std.mem.Allocator,
    learner_set: *learner.LearnerSet,
    rules_engine: *const rules.RulesEngine,
    path_finder: *pathfinder.Pathfinder,
    cluster_subnet_prefix: u32,

    pub fn init(
        allocator: std.mem.Allocator,
        learner_set: *learner.LearnerSet,
        rules_engine: *const rules.RulesEngine,
        path_finder: *pathfinder.Pathfinder,
    ) Router {
        return .{
            .allocator = allocator,
            .learner_set = learner_set,
            .rules_engine = rules_engine,
            .path_finder = path_finder,
            .cluster_subnet_prefix = ipam.Ipam.parseIpv4("10.42.0.0") & 0xffff0000,
        };
    }

    pub fn decide(self: *Router, dst_ip: u32, dst_port: u16, is_guest: bool) RouteAction {
        if ((dst_ip >> 24) == 127 or (dst_ip >> 24) == 10 and ((dst_ip >> 16) & 0xff) != 42) {
            return .direct;
        }

        if ((dst_ip & 0xffff0000) == self.cluster_subnet_prefix) {
            if (is_guest) {
                if (dst_port == 53) return .{ .mesh_internal = 1 };
                return .drop;
            }
            const target_node_id: u16 = @intCast(dst_ip & 0xff);
            return .{ .mesh_internal = target_node_id };
        }

        if (dst_port == 22 or dst_port == 123) {
            return .direct;
        }

        if (self.learner_set.has(dst_ip)) {
            return .direct;
        }

        if (self.rules_engine.isDomesticIp(dst_ip)) {
            return .direct;
        }

        if (self.path_finder.findBestRoute(1)) |path| {
            return .{ .tunnel_exit = path.next_hop };
        }

        return .direct;
    }
};
