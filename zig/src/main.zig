const std = @import("std");
const config_mod = @import("config.zig");
const engine_mod = @import("amnezia/engine.zig");
const protocol_mod = @import("amnezia/protocol.zig");
const router_mod = @import("routing/router.zig");
const learner_mod = @import("routing/learner.zig");
const rules_mod = @import("routing/rules.zig");

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
    jsonLog("INFO", "bootstrap", "starting", "Initializing unsafie node");

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

test "stun building and parsing" {
    var tx: [12]u8 = undefined;
    @memcpy(&tx, "1234567890ab");

    var req_buf: [32]u8 = undefined;
    const req_len = try protocol_mod.buildStunRequest(&req_buf, tx);
    try std.testing.expectEqual(@as(usize, 16), req_len);

    var resp_buf: [32]u8 = undefined;
    const resp_len = try protocol_mod.buildStunResponse(&resp_buf, tx, 0x4d583737, 51820);
    try std.testing.expectEqual(@as(usize, 22), resp_len);

    const parsed = protocol_mod.parseStunResponse(resp_buf[0..resp_len], tx);
    try std.testing.expect(parsed != null);
    try std.testing.expectEqual(@as(u32, 0x4d583737), parsed.?.ip);
    try std.testing.expectEqual(@as(u16, 51820), parsed.?.port);
}

test "rules engine matching" {
    const re = rules_mod.RulesEngine.initDefault();
    try std.testing.expect(re.matchDomain("yandex.ru"));
    try std.testing.expect(re.matchDomain("vk.com"));
    try std.testing.expect(!re.matchDomain("google.com"));

    const yandex_ip: u32 = (77 << 24) | (88 << 16) | (55 << 8) | 55;
    try std.testing.expect(re.matchIp(yandex_ip));

    const cloudflare_ip: u32 = (1 << 24) | (1 << 16) | (1 << 8) | 1;
    try std.testing.expect(!re.matchIp(cloudflare_ip));
}

test "smart router variant 3 local check" {
    var learner = learner_mod.LearnerSet.init(std.testing.allocator);
    defer learner.deinit();

    var router = router_mod.SmartRouter.init(std.testing.allocator, &learner, "tunnel", "10.42.0.0/16");
    defer router.deinit();

    router.is_russian_client = true;

    const yandex_ip: u32 = (77 << 24) | (88 << 16) | (55 << 8) | 55;
    const r_ru = router.decide(yandex_ip, null);
    try std.testing.expectEqual(router_mod.RouteAction.direct, r_ru);

    const foreign_ip: u32 = (1 << 24) | (1 << 16) | (1 << 8) | 1;
    const r_foreign = router.decide(foreign_ip, null);
    try std.testing.expectEqual(router_mod.RouteAction.mesh, r_foreign);
}

test "push reload signal" {
    var buf: [32]u8 = undefined;
    const len = try protocol_mod.buildPushReload(&buf, 1727210000);
    try std.testing.expectEqual(@as(usize, 16), len);

    const ptype = protocol_mod.identifyPacket(buf[0..len], .{});
    try std.testing.expectEqual(protocol_mod.PacketType.push_signal, ptype);
}

test "config token and servers roundtrip" {
    const sample =
        \\mode: "client"
        \\token: "my_secret_token"
        \\smart_routing: true
        \\servers:
        \\  - "198.51.100.1:51820"
        \\  - "198.51.100.2:51820"
    ;

    var cfg = try config_mod.parseYaml(std.testing.allocator, sample);
    defer cfg.deinit();

    try std.testing.expectEqual(config_mod.Mode.client, cfg.node.mode);
    try std.testing.expectEqualStrings("my_secret_token", cfg.node.token);
    try std.testing.expectEqual(@as(usize, 2), cfg.node.servers.len);
    try std.testing.expect(cfg.node.smart_routing);
}
