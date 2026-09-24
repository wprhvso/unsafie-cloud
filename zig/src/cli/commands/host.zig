const std = @import("std");
const client = @import("../client.zig");
const host_mod = @import("../../host/provisioner.zig");

pub fn execute(cl: client.Client, args: []const []const u8) !void {
    _ = args;
    std.debug.print("[HOST] Applying idempotent host configuration...\n", .{});

    const vpn_iface = std.posix.getenv("VPN_IFACE") orelse "unsafie0";
    const prov = host_mod.HostProvisioner.init(cl.allocator);
    prov.bootstrapAll(vpn_iface) catch |err| {
        std.debug.print("[HOST] Provisioning encountered an issue: {any}\n", .{err});
        return;
    };
    std.debug.print("[HOST] Local host provisioning completed successfully.\n", .{});
}
