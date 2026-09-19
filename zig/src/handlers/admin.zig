const std = @import("std");

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

    pub fn handleKernelUpgrade(allocator: std.mem.Allocator, params: ?std.json.Value) !std.json.Value {
        _ = allocator;
        _ = params;
        return std.json.Value{ .string = "kernel_upgrade_initiated" };
    }
};
