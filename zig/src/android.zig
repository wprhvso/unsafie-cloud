const std = @import("std");
const config_mod = @import("config.zig");
const engine_mod = @import("amnezia/engine.zig");
const log = @import("log.zig");

const embedded_unsafie_yaml = @embedFile("vpn/platform/unsafie.yaml");

var global_engine: ?*engine_mod.AmneziaEngine = null;

export fn Java_com_unsafie_vpn_NativeCore_startTunnel(env: *anyopaque, clazz: *anyopaque, fd: i32, mtu: i32) callconv(.c) i32 {
    _ = env;
    _ = clazz;

    log.infoFmt("android", "start_tunnel_req", "Android NativeCore startTunnel called with fd={d} mtu={d}", .{ fd, mtu });

    if (global_engine != null) {
        log.warn("android", "already_running", "Tunnel is already running in this process");
        return 0;
    }

    const allocator = std.heap.page_allocator;
    const cfg = config_mod.parseYaml(allocator, embedded_unsafie_yaml) catch |err| {
        log.errFmt("android", "config_parse_err", "Failed to parse embedded config: {any}", .{err});
        return -1;
    };
    var eng = engine_mod.AmneziaEngine.initWithFd(allocator, null, cfg, fd) catch |err| {
        log.errFmt("android", "engine_init_err", "Failed to init engine with fd: {any}", .{err});
        return -2;
    };
    eng.start() catch |err| {
        log.errFmt("android", "engine_start_err", "Failed to start engine: {any}", .{err});
        return -3;
    };
    global_engine = eng;
    log.info("android", "tunnel_started", "Android VPN tunnel started successfully");
    return 0;
}

export fn Java_com_unsafie_vpn_NativeCore_stopTunnel(env: *anyopaque, clazz: *anyopaque) callconv(.c) void {
    _ = env;
    _ = clazz;
    log.info("android", "stop_tunnel_req", "Android NativeCore stopTunnel called");
    if (global_engine) |eng| {
        eng.stop();
        eng.deinit();
        global_engine = null;
        log.info("android", "tunnel_stopped", "Android VPN tunnel stopped and engine deinitialized");
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
    log.debugFmt("android", "protect_socket", "Socket protection requested for fd={d}", .{socket_fd});
    return 0;
}
