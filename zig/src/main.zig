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

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();

    _ = args.skip();
    if (args.next()) |subcmd| {
        if (std.mem.eql(u8, subcmd, "host-setup") or std.mem.eql(u8, subcmd, "bootstrap")) {
            var cfg = try config.Config.load(allocator);
            defer cfg.deinit(allocator);

            const prov = host_mod.HostProvisioner.init(allocator);
            try prov.bootstrapAll(cfg.vpn_iface);
            std.debug.print("Host provisioning completed successfully\n", .{});
            return;
        }
    }

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

    const edge_server = edge.EdgeServer.init(cfg.http_port, cfg.https_port);
    try edge_server.start();

    const ws_server = ws.WsServer.init(cfg.rpc_port);
    try ws_server.start();

    watchdog.SystemdWatchdog.notifyReady();
    watchdog.SystemdWatchdog.notifyWatchdog();

    std.debug.print("Unsafie Cloud SQLite-WAL, Event-Ledger & Mesh kernel initialized successfully\n", .{});
}
