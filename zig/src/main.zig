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

    var args = std.process.argsWithAllocator(allocator) catch |err| {
        jsonLog("ERROR", "bootstrap", "args_error", @errorName(err));
        return err;
    };
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
    jsonLog("INFO", "bootstrap", "daemon_start", "Initializing Unsafie Cloud daemon in server mode");

    var cfg = config.Config.load(allocator) catch |err| {
        jsonLog("ERROR", "config", "load_failed", @errorName(err));
        return err;
    };
    defer cfg.deinit(allocator);
    jsonLog("INFO", "config", "loaded", "Configuration parameters loaded successfully");

    const git_store = git_state.GitStore.init(allocator, cfg.state_dir);
    git_store.ensureRepo() catch |err| {
        jsonLog("WARN", "git", "repo_init_warning", @errorName(err));
    };

    const storage = disk_storage.DiskStorage.init(cfg.storage_dir);
    storage.ensureDirs() catch |err| {
        jsonLog("WARN", "storage", "dirs_warning", @errorName(err));
    };

    std.fs.cwd().makePath(cfg.state_dir) catch {};
    const db_file_path = std.fs.path.join(allocator, &[_][]const u8{ cfg.state_dir, "unsafie.db" }) catch |err| {
        jsonLog("ERROR", "db", "path_join_error", @errorName(err));
        return err;
    };
    defer allocator.free(db_file_path);

    var sqlite_db = db_mod.SqliteDb.init(allocator, db_file_path) catch |err| {
        jsonLog("ERROR", "db", "sqlite_open_error", @errorName(err));
        return err;
    };
    defer sqlite_db.deinit();
    jsonLog("INFO", "db", "sqlite_ready", "SQLite database opened with WAL mode and cluster_logs schema");

    var logger = logger_mod.StructuredLogger.init(allocator, "server-node", sqlite_db);
    logger.logSystem("INFO", "kernel", "daemon_start", "Unsafie Cloud Sovereign Node initialized");

    var ledger_engine = ledger.LedgerEngine.init(allocator, 1, cfg.state_dir) catch |err| {
        jsonLog("WARN", "ledger", "init_warning", @errorName(err));
        return err;
    };
    defer ledger_engine.deinit();
    _ = ledger_engine.emit(.node_heartbeat, "{}") catch {};

    var vpn_service = vpn.VpnService.init(allocator, cfg.vpn_iface, cfg.vpn_subnet) catch |err| {
        jsonLog("ERROR", "vpn", "service_init_error", @errorName(err));
        return err;
    };
    defer vpn_service.deinit();
    jsonLog("INFO", "vpn", "service_ready", "TUN interface and mesh network core initialized");

    vpn_service.setLogger(&logger);
    vpn_service.setKeyFromToken(cfg.admin_token);
    vpn_service.startServer() catch |err| {
        jsonLog("ERROR", "vpn", "start_server_error", @errorName(err));
        return err;
    };
    jsonLog("INFO", "vpn", "server_listening", "DNS server and internal packet routing active");

    var edge_server = edge.EdgeServer.init(cfg.http_port, cfg.https_port);
    edge_server.setLogger(&logger);
    edge_server.start(vpn_service.key, &vpn_service.tun_dev) catch |err| {
        jsonLog("ERROR", "edge", "start_error", @errorName(err));
    };
    defer edge_server.stop();
    jsonLog("INFO", "edge", "listeners_ready", "Unified port 443 listeners active for MASQUE and WebSocket");

    const ws_server = ws.WsServer.init(cfg.rpc_port);
    ws_server.start() catch {};

    watchdog.SystemdWatchdog.notifyReady();
    watchdog.SystemdWatchdog.notifyWatchdog();

    jsonLog("INFO", "runtime", "running", "Unsafie Cloud server daemon is fully operational and listening");

    while (!should_exit.load(.seq_cst)) {
        std.Thread.sleep(1 * std.time.ns_per_s);
        watchdog.SystemdWatchdog.notifyWatchdog();
    }

    jsonLog("INFO", "runtime", "shutting_down", "Received termination signal, stopping daemon");
    logger.logSystem("INFO", "kernel", "daemon_stop", "Unsafie Cloud daemon stopping");
    vpn_service.stop();
    jsonLog("INFO", "runtime", "stopped", "Unsafie Cloud server stopped cleanly");
}

pub fn runClient(allocator: std.mem.Allocator, endpoint: []const u8, token: []const u8) !void {
    setupSignals();
    jsonLog("INFO", "bootstrap", "client_start", "Initializing Unsafie Cloud in client mode");

    var cfg = config.Config.load(allocator) catch |err| {
        jsonLog("ERROR", "config", "load_failed", @errorName(err));
        return err;
    };
    defer cfg.deinit(allocator);

    std.fs.cwd().makePath(cfg.state_dir) catch {};

    const db_file_path = std.fs.path.join(allocator, &[_][]const u8{ cfg.state_dir, "unsafie.db" }) catch |err| {
        jsonLog("ERROR", "db", "path_join_error", @errorName(err));
        return err;
    };
    defer allocator.free(db_file_path);

    var sqlite_db = db_mod.SqliteDb.init(allocator, db_file_path) catch |err| {
        jsonLog("WARN", "db", "sqlite_warning", @errorName(err));
        return err;
    };
    defer sqlite_db.deinit();
    jsonLog("INFO", "db", "sqlite_ready", "Client local SQLite database ready");

    var logger = logger_mod.StructuredLogger.init(allocator, "client-node", sqlite_db);
    logger.logSystem("INFO", "client", "connect_init", "Client starting connection to VPS");

    var vpn_service = vpn.VpnService.init(allocator, cfg.vpn_iface, cfg.vpn_subnet) catch |err| {
        jsonLog("ERROR", "vpn", "init_failed", @errorName(err));
        return err;
    };
    defer vpn_service.deinit();
    jsonLog("INFO", "vpn", "tun_ready", "Virtual network interface initialized");

    vpn_service.setLogger(&logger);
    vpn_service.setKeyFromToken(token);

    const prov = host_mod.HostProvisioner.init(allocator);
    prov.setupClientRoutes(cfg.vpn_iface, endpoint);
    defer prov.teardownClientRoutes(cfg.vpn_iface);
    jsonLog("INFO", "route", "routes_applied", "Smart routing half-subnets and server pin-route applied");

    vpn_service.startClient(endpoint) catch |err| {
        jsonLog("ERROR", "vpn", "connect_failed", @errorName(err));
        return err;
    };
    jsonLog("INFO", "client", "connected", "Connected to remote sovereign node endpoint");

    jsonLog("INFO", "runtime", "running", "Client tunnel active, domestic Russian traffic routed direct, world via mesh");

    while (!should_exit.load(.seq_cst)) {
        std.Thread.sleep(1 * std.time.ns_per_s);
    }

    jsonLog("INFO", "runtime", "disconnecting", "Shutting down client and restoring network configuration");
    logger.logSystem("INFO", "client", "disconnect", "Client stopping connection");
    vpn_service.stop();
    jsonLog("INFO", "runtime", "stopped", "Client disconnected and routes restored cleanly");
}
