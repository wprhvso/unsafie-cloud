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
const logger_mod = @import("logging/logger.zig");

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

    var logger = logger_mod.StructuredLogger.init(allocator, "server-node", sqlite_db);
    logger.logSystem("INFO", "kernel", "daemon_start", "Unsafie Cloud Sovereign Node initialized with SQLite database logging");

    var ledger_engine = try ledger.LedgerEngine.init(allocator, 1, cfg.state_dir);
    defer ledger_engine.deinit();
    _ = try ledger_engine.emit(.node_heartbeat, "{}");

    var vpn_service = try vpn.VpnService.init(allocator, cfg.vpn_iface, cfg.vpn_subnet);
    defer vpn_service.deinit();

    vpn_service.setLogger(&logger);
    vpn_service.setKeyFromToken(cfg.admin_token);
    try vpn_service.startServer();

    var edge_server = edge.EdgeServer.init(cfg.http_port, cfg.https_port);
    edge_server.setLogger(&logger);
    try edge_server.start(vpn_service.key, &vpn_service.tun_dev);
    defer edge_server.stop();

    const ws_server = ws.WsServer.init(cfg.rpc_port);
    try ws_server.start();

    watchdog.SystemdWatchdog.notifyReady();
    watchdog.SystemdWatchdog.notifyWatchdog();

    std.debug.print("Unsafie Cloud daemon active on port {d} (logs stored in {s}/unsafie.db)\n", .{ cfg.https_port, cfg.state_dir });
    std.debug.print("Run 'unsafie-cloud logs' to inspect structured events in JSON.\n", .{});

    while (!should_exit.load(.seq_cst)) {
        std.Thread.sleep(1 * std.time.ns_per_s);
        watchdog.SystemdWatchdog.notifyWatchdog();
    }

    logger.logSystem("INFO", "kernel", "daemon_stop", "Unsafie Cloud daemon stopping");
    vpn_service.stop();
}

pub fn runClient(allocator: std.mem.Allocator, endpoint: []const u8, token: []const u8) !void {
    setupSignals();

    var cfg = try config.Config.load(allocator);
    defer cfg.deinit(allocator);

    std.fs.cwd().makePath(cfg.state_dir) catch {};

    const db_file_path = try std.fs.path.join(allocator, &[_][]const u8{ cfg.state_dir, "unsafie.db" });
    defer allocator.free(db_file_path);
    var sqlite_db = try db_mod.SqliteDb.init(allocator, db_file_path);
    defer sqlite_db.deinit();

    var logger = logger_mod.StructuredLogger.init(allocator, "client-node", sqlite_db);
    logger.logSystem("INFO", "client", "connect_init", "Client starting connection to VPS");

    var vpn_service = try vpn.VpnService.init(allocator, cfg.vpn_iface, cfg.vpn_subnet);
    defer vpn_service.deinit();

    vpn_service.setLogger(&logger);
    vpn_service.setKeyFromToken(token);

    const prov = host_mod.HostProvisioner.init(allocator);
    prov.setupClientRoutes(cfg.vpn_iface, endpoint);
    defer prov.teardownClientRoutes(cfg.vpn_iface);

    try vpn_service.startClient(endpoint);

    std.debug.print("Unsafie Cloud VPN connected to {s} (logs stored in {s}/unsafie.db)\n", .{ endpoint, cfg.state_dir });
    std.debug.print("Run 'unsafie-cloud logs' to inspect structured events in JSON.\n", .{});

    while (!should_exit.load(.seq_cst)) {
        std.Thread.sleep(1 * std.time.ns_per_s);
    }

    logger.logSystem("INFO", "client", "disconnect", "Client stopping connection");
    vpn_service.stop();
}
