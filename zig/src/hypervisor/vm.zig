const std = @import("std");
const socket = @import("socket.zig");

pub const HypervisorVm = struct {
    sock: socket.IncusSocket,

    pub fn init(sock: socket.IncusSocket) HypervisorVm {
        return .{ .sock = sock };
    }

    pub fn createInstance(self: HypervisorVm, allocator: std.mem.Allocator, name: []const u8, vcpus: i32, ram_mb: i32) !void {
        _ = self;
        _ = allocator;
        _ = name;
        _ = vcpus;
        _ = ram_mb;
    }

    pub fn startInstance(self: HypervisorVm, name: []const u8) !void {
        _ = self;
        _ = name;
    }

    pub fn stopInstance(self: HypervisorVm, name: []const u8) !void {
        _ = self;
        _ = name;
    }

    pub fn deleteInstance(self: HypervisorVm, name: []const u8) !void {
        _ = self;
        _ = name;
    }
};
