const std = @import("std");
const event = @import("event.zig");

pub const NodeState = struct {
    name: []const u8,
    ip: []const u8,
    role: []const u8,
    active: bool = true,
};

pub const VmState = struct {
    name: []const u8,
    status: []const u8,
};

pub const EventReducer = struct {
    allocator: std.mem.Allocator,
    nodes: std.StringHashMap(NodeState),
    vms: std.StringHashMap(VmState),

    pub fn init(allocator: std.mem.Allocator) EventReducer {
        return .{
            .allocator = allocator,
            .nodes = std.StringHashMap(NodeState).init(allocator),
            .vms = std.StringHashMap(VmState).init(allocator),
        };
    }

    pub fn deinit(self: *EventReducer) void {
        var it_nodes = self.nodes.iterator();
        while (it_nodes.next()) |entry| {
            self.allocator.free(entry.value_ptr.name);
            self.allocator.free(entry.value_ptr.ip);
            self.allocator.free(entry.value_ptr.role);
        }
        self.nodes.deinit();

        var it_vms = self.vms.iterator();
        while (it_vms.next()) |entry| {
            self.allocator.free(entry.value_ptr.name);
            self.allocator.free(entry.value_ptr.status);
        }
        self.vms.deinit();
    }

    pub fn apply(self: *EventReducer, event_code: u16, payload: []const u8) !void {
        _ = payload;
        switch (event_code) {
            0x0101 => {
                const name = try self.allocator.dupe(u8, "node");
                const ip = try self.allocator.dupe(u8, "10.42.0.1");
                const role = try self.allocator.dupe(u8, "core");
                try self.nodes.put(name, .{ .name = name, .ip = ip, .role = role });
            },
            0x0401 => {
                const name = try self.allocator.dupe(u8, "vm");
                const status = try self.allocator.dupe(u8, "defined");
                try self.vms.put(name, .{ .name = name, .status = status });
            },
            0x0402 => {
                const name = try self.allocator.dupe(u8, "vm");
                const status = try self.allocator.dupe(u8, "running");
                try self.vms.put(name, .{ .name = name, .status = status });
            },
            else => {},
        }
    }
};
