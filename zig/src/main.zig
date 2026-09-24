const std = @import("std");
const config_mod = @import("config.zig");
const engine_mod = @import("amnezia/engine.zig");
const protocol_mod = @import("amnezia/protocol.zig");
const router_mod = @import("routing/router.zig");
const learner_mod = @import("routing/learner.zig");
const sync_mod = @import("sync/mesh_sync.zig");

var should_exit = std.atomic.Value(bool).init(false);

fn handleSignal(sig: i32) callconv(.c) void {
    _ = sig;
    should_exit.store(true, .seq_cst);
}

fn setupSignals() void {
    const act = std.posix.Sigaction{
        .handler = .{ .handler = handleSignal },
        .mask = std.posix.sigemptyset(),
        .flags = 0,
    };
    std.posix.sigaction(std.posix.SIG.INT, &act, null);
    std.posix.sigaction(std.posix.SIG.TERM, &act, null);
}

fn jsonLog(level: []const u8, subsystem: []const u8, event: []const u8, message: []const u8) void {
    const ts = std.time.milliTimestamp();
    std.debug.print(
        "{{\"ts\":{d},\"level\":\"{s}\",\"subsystem\":\"{s}\",\"event\":\"{s}\",\"message\":\"{s}\"}}\n",
        .{ ts, level, subsystem, event, message },
    );
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();

    _ = args.skip();
    var config_path: []const u8 = "unsafie.yaml";
    if (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
            std.debug.print("Usage: unsafie [path/to/unsafie.yaml]\n", .{});
            return;
        }
        config_path = arg;
    }

    setupSignals();
    jsonLog("INFO", "bootstrap", "starting", "Initializing unsafie in-memory node");

    const cfg = config_mod.loadFromFile(allocator, config_path) catch |err| {
        jsonLog("ERROR", "config", "load_failed", @errorName(err));
        return err;
    };
    jsonLog("INFO", "config", "loaded", "Configuration loaded into memory");

    var engine = engine_mod.AmneziaEngine.init(allocator, config_path, cfg) catch |err| {
        jsonLog("ERROR", "amnezia", "init_failed", @errorName(err));
        return err;
    };
    defer engine.deinit();

    engine.start() catch |err| {
        jsonLog("ERROR", "amnezia", "start_failed", @errorName(err));
        return err;
    };
    jsonLog("INFO", "amnezia", "running", "AmneziaWG node active with in-memory state and smart routing");

    while (!should_exit.load(.seq_cst)) {
        std.Thread.sleep(100 * std.time.ns_per_ms);
    }

    jsonLog("INFO", "bootstrap", "stopping", "Stopping unsafie node");
    engine.stop();
    jsonLog("INFO", "bootstrap", "stopped", "Unsafie stopped cleanly");
}

test "config roundtrip" {
    const sample =
        \\metadata:
        \\  version: 1
        \\  timestamp: 1727210000
        \\  updated_by: "test-node"
        \\
        \\node:
        \\  name: "test-node"
        \\  role: "admin"
        \\  listen_port: 51820
        \\  vpn_ip: "10.42.0.1"
        \\
        \\amnezia:
        \\  jc: 4
        \\  jmin: 40
        \\  jmax: 70
        \\  s1: 64
        \\  s2: 48
        \\  h1: 1287634912
        \\  h2: 837194625
        \\  h3: 1092837465
        \\  h4: 1982736450
        \\  psk: "test_psk"
        \\
        \\roles:
        \\  - name: "admin"
        \\    permissions:
        \\      - "sync_config"
        \\      - "route_all"
        \\
        \\peers:
        \\  - name: "peer1"
        \\    role: "client"
        \\    public_key: "abc123"
        \\    endpoint: "1.2.3.4:51820"
        \\    can_sync_config: false
        \\    persistent_keepalive: 25
        \\    allowed_ips:
        \\      - "10.42.0.2/32"
        \\
        \\routing:
        \\  default_action: "tunnel"
        \\  direct_domains:
        \\    - "*.ru"
        \\  direct_cidrs:
        \\    - "10.0.0.0/8"
        \\  blocked_domains:
        \\    - "ads.example.com"
        \\  routed_domains:
        \\    - "*.internal"
        \\
        \\dns:
        \\  listen: "10.42.0.1:53"
        \\  upstreams:
        \\    - "1.1.1.1:53"
        \\  hosts:
        \\    - name: "node1.internal"
        \\      ip: "10.42.0.1"
    ;

    var cfg1 = try config_mod.parseYaml(std.testing.allocator, sample);
    defer cfg1.deinit();

    var buf = std.ArrayList(u8){};
    defer buf.deinit(std.testing.allocator);
    try cfg1.serialize(buf.writer(std.testing.allocator));

    var cfg2 = try config_mod.parseYaml(std.testing.allocator, buf.items);
    defer cfg2.deinit();

    try std.testing.expectEqual(cfg1.metadata.version, cfg2.metadata.version);
    try std.testing.expectEqual(cfg1.metadata.timestamp, cfg2.metadata.timestamp);
    try std.testing.expectEqualStrings(cfg1.node.name, cfg2.node.name);
    try std.testing.expectEqual(cfg1.amnezia.h1, cfg2.amnezia.h1);
    try std.testing.expectEqual(cfg1.roles.len, cfg2.roles.len);
    try std.testing.expectEqual(cfg1.peers.len, cfg2.peers.len);
}

test "amnezia packet identification" {
    const params = protocol_mod.AmneziaParams{
        .h1 = 0x11111111,
        .h2 = 0x22222222,
        .h3 = 0x33333333,
        .h4 = 0x44444444,
    };

    var h1_bytes: [4]u8 = undefined;
    std.mem.writeInt(u32, &h1_bytes, 0x11111111, .little);
    try std.testing.expectEqual(protocol_mod.PacketType.handshake_init, protocol_mod.identifyPacket(h1_bytes, params));

    var h4_bytes: [4]u8 = undefined;
    std.mem.writeInt(u32, &h4_bytes, 0x44444444, .little);
    try std.testing.expectEqual(protocol_mod.PacketType.transport_data, protocol_mod.identifyPacket(h4_bytes, params));

    var sync_bytes: [4]u8 = undefined;
    std.mem.writeInt(u32, &sync_bytes, protocol_mod.SYNC_MAGIC, .little);
    try std.testing.expectEqual(protocol_mod.PacketType.mesh_sync, protocol_mod.identifyPacket(sync_bytes, params));
}

test "smart router decisions" {
    var learner = learner_mod.LearnerSet.init(std.testing.allocator);
    defer learner.deinit();

    var router = router_mod.SmartRouter.init(std.testing.allocator, &learner, "tunnel", "10.42.0.0/16");
    defer router.deinit();

    try router.addDirectCidr("192.168.0.0/16");
    try router.addDirectDomain("*.ru");
    try router.addBlockedDomain("adservice.google.com");

    const r_direct_cidr = router.decide(router_mod.parseIpv4("192.168.1.1").?, null);
    try std.testing.expectEqual(router_mod.RouteAction.direct, r_direct_cidr);

    const r_blocked = router.decide(router_mod.parseIpv4("8.8.8.8").?, "adservice.google.com");
    try std.testing.expectEqual(router_mod.RouteAction.drop, r_blocked);

    const r_ru = router.decide(router_mod.parseIpv4("77.88.55.55").?, "yandex.ru");
    try std.testing.expectEqual(router_mod.RouteAction.direct, r_ru);

    const r_ru_learned = router.decide(router_mod.parseIpv4("77.88.55.55").?, null);
    try std.testing.expectEqual(router_mod.RouteAction.direct, r_ru_learned);

    const r_mesh_internal = router.decide(router_mod.parseIpv4("10.42.0.5").?, null);
    try std.testing.expectEqual(router_mod.RouteAction.mesh, r_mesh_internal);

    const r_foreign = router.decide(router_mod.parseIpv4("1.1.1.1").?, "foreign.com");
    try std.testing.expectEqual(router_mod.RouteAction.mesh, r_foreign);
}
