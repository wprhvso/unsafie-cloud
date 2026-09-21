const std = @import("std");
const host = @import("../host/provisioner.zig");

pub const Bootstrapper = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Bootstrapper {
        return .{ .allocator = allocator };
    }

    pub fn bootstrapLocal(self: Bootstrapper, vpn_iface: []const u8) !void {
        const prov = host.HostProvisioner.init(self.allocator);
        try prov.bootstrapAll(vpn_iface);
    }

    pub fn bootstrapNode(self: Bootstrapper, target_ip: []const u8, extra_vars: ?[]const u8) !void {
        _ = extra_vars;
        var child = std.process.Child.init(&[_][]const u8{
            "ssh", "-o", "StrictHostKeyChecking=no", target_ip, "unsafie", "host", "bootstrap",
        }, self.allocator);
        _ = child.spawnAndWait() catch {};
    }
};
