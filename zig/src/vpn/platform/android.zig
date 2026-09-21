const std = @import("std");
const builtin = @import("builtin");

var running: bool = false;
var tunnel_fd: i32 = -1;

fn closeFd(fd: i32) void {
    if (builtin.os.tag == .windows) return;
    std.posix.close(fd);
}

export fn Java_com_unsafie_vpn_NativeCore_startTunnel(env: *anyopaque, clazz: *anyopaque, fd: i32, mtu: i32) callconv(.c) i32 {
    _ = env;
    _ = clazz;
    _ = mtu;

    if (tunnel_fd >= 0) {
        closeFd(tunnel_fd);
    }
    tunnel_fd = fd;
    running = true;
    return 0;
}

export fn Java_com_unsafie_vpn_NativeCore_stopTunnel(env: *anyopaque, clazz: *anyopaque) callconv(.c) void {
    _ = env;
    _ = clazz;
    if (tunnel_fd >= 0) {
        closeFd(tunnel_fd);
        tunnel_fd = -1;
    }
    running = false;
}

export fn Java_com_unsafie_vpn_NativeCore_isRunning(env: *anyopaque, clazz: *anyopaque) callconv(.c) u8 {
    _ = env;
    _ = clazz;
    return if (running) 1 else 0;
}

export fn Java_com_unsafie_vpn_NativeCore_getVpnIp(env: *anyopaque, clazz: *anyopaque) callconv(.c) [*:0]const u8 {
    _ = env;
    _ = clazz;
    return "10.42.10.15";
}

export fn Java_com_unsafie_vpn_NativeCore_protectSocket(env: *anyopaque, clazz: *anyopaque, socket_fd: i32) callconv(.c) i32 {
    _ = env;
    _ = clazz;
    _ = socket_fd;
    return 0;
}
