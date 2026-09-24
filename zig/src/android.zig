const std = @import("std");
const config_mod = @import("config.zig");
const engine_mod = @import("amnezia/engine.zig");

const embedded_unsafie_yaml = @embedFile("vpn/platform/unsafie.yaml");

var global_engine: ?*engine_mod.AmneziaEngine = null;

export fn Java_com_unsafie_vpn_NativeCore_startTunnel(env: *anyopaque, clazz: *anyopaque, fd: i32, mtu: i32) callconv(.c) i32 {
    _ = env;
    _ = clazz;
    _ = mtu;

    if (global_engine != null) {
        return 0;
    }

    const allocator = std.heap.page_allocator;
    const cfg = config_mod.parseYaml(allocator, embedded_unsafie_yaml) catch return -1;
    var eng = engine_mod.AmneziaEngine.initWithFd(allocator, null, cfg, fd) catch return -2;
    eng.start() catch return -3;
    global_engine = eng;
    return 0;
}

export fn Java_com_unsafie_vpn_NativeCore_stopTunnel(env: *anyopaque, clazz: *anyopaque) callconv(.c) void {
    _ = env;
    _ = clazz;
    if (global_engine) |eng| {
        eng.stop();
        eng.deinit();
        global_engine = null;
    }
}

export fn Java_com_unsafie_vpn_NativeCore_isRunning(env: *anyopaque, clazz: *anyopaque) callconv(.c) u8 {
    _ = env;
    _ = clazz;
    if (global_engine) |eng| {
        return if (eng.running.load(.seq_cst)) 1 else 0;
    }
    return 0;
}

export fn Java_com_unsafie_vpn_NativeCore_getVpnIp(env: *anyopaque, clazz: *anyopaque) callconv(.c) [*:0]const u8 {
    _ = env;
    _ = clazz;
    return "10.42.0.2";
}

export fn Java_com_unsafie_vpn_NativeCore_protectSocket(env: *anyopaque, clazz: *anyopaque, socket_fd: i32) callconv(.c) i32 {
    _ = env;
    _ = clazz;
    _ = socket_fd;
    return 0;
}
