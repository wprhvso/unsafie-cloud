const std = @import("std");

pub const PortProxy = struct {
    pub fn addProxyDevice(vm_name: []const u8, protocol: []const u8, host_port: u16, target_port: u16) !void {
        _ = vm_name;
        _ = protocol;
        _ = host_port;
        _ = target_port;
    }

    pub fn removeProxyDevice(vm_name: []const u8, host_port: u16) !void {
        _ = vm_name;
        _ = host_port;
    }
};
