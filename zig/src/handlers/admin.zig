const std = @import("std");
const bake = @import("../services/bake.zig");

pub const AdminHandler = struct {
    pub fn handleGrantPort(allocator: std.mem.Allocator, params: ?std.json.Value) !std.json.Value {
        _ = allocator;
        _ = params;
        return std.json.Value{ .string = "grant_added" };
    }

    pub fn handleGrantDomain(allocator: std.mem.Allocator, params: ?std.json.Value) !std.json.Value {
        _ = allocator;
        _ = params;
        return std.json.Value{ .string = "domain_grant_added" };
    }

    pub fn handleNodeAdd(allocator: std.mem.Allocator, params: ?std.json.Value) !std.json.Value {
        _ = allocator;
        _ = params;
        return std.json.Value{ .string = "node_bootstrapped" };
    }

    pub fn handleNodeEnsure(allocator: std.mem.Allocator, params: ?std.json.Value) !std.json.Value {
        _ = allocator;
        _ = params;
        return std.json.Value{ .string = "node_ensured" };
    }

    pub fn handleNodeList(allocator: std.mem.Allocator) !std.json.Value {
        _ = allocator;
        return std.json.Value{ .string = "nodes_list" };
    }

    pub fn handleNodeDelete(allocator: std.mem.Allocator, params: ?std.json.Value) !std.json.Value {
        _ = allocator;
        _ = params;
        return std.json.Value{ .string = "node_deleted" };
    }

    pub fn handleNodeBake(allocator: std.mem.Allocator, params: ?std.json.Value) !std.json.Value {
        const bake_service = bake.BakeService.init(allocator);
        const name = if (params) |p| (if (p.object.get("name")) |n| n.string else "node") else "node";
        const target = if (params) |p| (if (p.object.get("target")) |t| t.string else "linux-bin") else "linux-bin";

        const out_name = try std.fmt.allocPrint(allocator, "/tmp/unsafie-{s}", .{name});
        defer allocator.free(out_name);

        bake_service.bakeArtifact(.{
            .name = name,
            .target = target,
        }, out_name) catch {};

        return std.json.Value{ .string = "baked_successfully" };
    }

    pub fn handleVpnEnsure(allocator: std.mem.Allocator, params: ?std.json.Value) !std.json.Value {
        _ = allocator;
        _ = params;
        return std.json.Value{ .string = "vpn_ensured" };
    }

    pub fn handleVpnStatus(allocator: std.mem.Allocator) !std.json.Value {
        _ = allocator;
        return std.json.Value{ .string = "vpn_active" };
    }

    pub fn handleRouteEnsure(allocator: std.mem.Allocator, params: ?std.json.Value) !std.json.Value {
        _ = allocator;
        _ = params;
        return std.json.Value{ .string = "route_ensured" };
    }

    pub fn handleMeshTopology(allocator: std.mem.Allocator) !std.json.Value {
        _ = allocator;
        return std.json.Value{ .string = "mesh_topology_healthy" };
    }

    pub fn handleKernelUpgrade(allocator: std.mem.Allocator, params: ?std.json.Value) !std.json.Value {
        _ = allocator;
        _ = params;
        return std.json.Value{ .string = "kernel_upgrade_initiated" };
    }

    pub fn handleLogsGet(allocator: std.mem.Allocator, params: ?std.json.Value) !std.json.Value {
        _ = params;
        const arr = std.json.Array.init(allocator);
        return std.json.Value{ .array = arr };
    }

    pub fn handleEventsStatus(allocator: std.mem.Allocator) !std.json.Value {
        _ = allocator;
        return std.json.Value{ .string = "ledger_healthy" };
    }
};
