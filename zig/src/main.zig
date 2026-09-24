const std = @import("std");
const config = @import("config.zig");
const git_state = @import("state/git.zig");
const disk_storage = @import("storage/disk.zig");
const edge = @import("edge/server.zig");
const ws = @import("ws/server.zig");
const watchdog = @import("cluster/watchdog.zig");
const vpn = @import("vpn/service.zig");
const ledger = @import("ledger/engine.zig");
const db_mod = @import("db/sqlite.zig");
const host_mod = @import("host/provisioner.zig");
const cli = @import("cli/main.zig");

var should_exit = std.atomic.Value(bool).init(false);

fn handleSignal(sig: i32) callconv(.c) void {
    _ = sig;
    should_exit.store(true, .seq_cst);
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();

    _ = args.skip();
    if (args.next()) |cmd| {
        if (std.mem.eql(u8, cmd, "run") or std.mem.eql(u8, cmd, "daemon") or std.mem.eql(u8, cmd, "server")) {
            return runDaemon(allocator);
        } else if (std.mem.eql(u8, cmd, "connect")) {
            const endpoint = args.next() orelse "127.0.0.1:443";
            var token: []const u8 = "default_admin_token";
            while (args.next()) |opt| {
                if (std.mem.eql(u8, opt, "--token") or std.mem.eql(u8, opt, "-t")) {
                    if (args.next()) |t| token = t;
                }
            }
            return runClient(allocator, endpoint, token);
        } else if (std.mem.eql(u8, cmd, "help") or std.mem.eql(u8, cmd, "--help") or std.mem.eql(u8, cmd, "-h")) {
            cli.printHelp();
            return;
        } else {
            var subargs = std.ArrayList([]const u8){};
            defer subargs.deinit(allocator);
            while (args.next()) |arg| {
                try subargs.append(allocator, arg);
            }
            return cli.execute(allocator, cmd, subargs.items);
        }
    }

    return runDaemon(allocator);
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

pub fn runDaemon(allocator: std.mem.Allocator) !void {
    setupSignals();

    var cfg = try config.Config.load(allocator);
    defer cfg.deinit(allocator);

    const git_store = git_state.GitStore.init(allocator, cfg.state_dir);
    try git_store.ensureRepo();

    const storage = disk_storage.DiskStorage.init(cfg.storage_dir);
    try storage.ensureDirs();

    const db_file_path = try std.fs.path.join(allocator, &[_][]const u8{ cfg.state_dir, "unsafie.db" });
    defer allocator.free(db_file_path);
    var sqlite_db = try db_mod.SqliteDb.init(allocator, db_file_path);
    defer sqlite_db.deinit();

    try sqlite_db.insertLog(std.time.milliTimestamp(), "node1", "INFO", "kernel", "kernel initialized with sqlite wal & fts5");

    var ledger_engine = try ledger.LedgerEngine.init(allocator, 1, cfg.state_dir);
    defer ledger_engine.deinit();
    _ = try ledger_engine.emit(.node_heartbeat, "{}");

    var vpn_service = try vpn.VpnService.init(allocator, cfg.vpn_iface, cfg.vpn_subnet);
    defer vpn_service.deinit();

    vpn_service.setKeyFromToken(cfg.admin_token);
    try vpn_service.startServer();

    var edge_server = edge.EdgeServer.init(cfg.http_port, cfg.https_port);
    try edge_server.start(vpn_service.key, &vpn_service.tun_dev);
    defer edge_server.stop();

    const ws_server = ws.WsServer.init(cfg.rpc_port);
    try ws_server.start();

    watchdog.SystemdWatchdog.notifyReady();
    watchdog.SystemdWatchdog.notifyWatchdog();

    std.debug.print("Unsafie Cloud Unified Sovereign Node running on port {d}\n", .{cfg.https_port});

    while (!should_exit.load(.seq_cst)) {
        std.Thread.sleep(1 * std.time.ns_per_s);
        watchdog.SystemdWatchdog.notifyWatchdog();
    }

    std.debug.print("\nStopping Unsafie Cloud daemon...\n", .{});
    vpn_service.stop();
}

pub fn runClient(allocator: std.mem.Allocator, endpoint: []const u8, token: []const u8) !void {
    setupSignals();

    var cfg = try config.Config.load(allocator);
    defer cfg.deinit(allocator);

    const prov = host_mod.HostProvisioner.init(allocator);
    prov.setupClientRoutes(cfg.vpn_iface, endpoint);
    defer prov.teardownClientRoutes(cfg.vpn_iface);

    var vpn_service = try vpn.VpnService.init(allocator, cfg.vpn_iface, cfg.vpn_subnet);
    defer vpn_service.deinit();

    vpn_service.setKeyFromToken(token);
    try vpn_service.startClient(endpoint);

    std.debug.print("Unsafie Cloud VPN Client connected to {s} (interface {s})\n", .{ endpoint, cfg.vpn_iface });
    std.debug.print("Routing domestic Russian traffic directly, overseas traffic via sovereign mesh.\n", .{});

    while (!should_exit.load(.seq_cst)) {
        std.Thread.sleep(1 * std.time.ns_per_s);
    }

    std.debug.print("\nDisconnecting VPN client...\n", .{});
    vpn_service.stop();
}
