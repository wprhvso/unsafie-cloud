const std = @import("std");

const c = @cImport({
    @cInclude("sqlite3.h");
});

pub const LogMatch = struct {
    ts: i64,
    node: []const u8,
    level: []const u8,
    comp: []const u8,
    message: []const u8,
};

pub const SqliteDb = struct {
    allocator: std.mem.Allocator,
    handle: ?*c.sqlite3,

    pub fn init(allocator: std.mem.Allocator, path: []const u8) !*SqliteDb {
        const self = try allocator.create(SqliteDb);
        errdefer allocator.destroy(self);

        self.allocator = allocator;

        const path_z = try allocator.dupeZ(u8, path);
        defer allocator.free(path_z);

        var db: ?*c.sqlite3 = null;
        if (c.sqlite3_open(path_z, &db) != c.SQLITE_OK) {
            return error.SqliteOpenFailed;
        }
        self.handle = db;

        try self.initSchema();
        return self;
    }

    pub fn deinit(self: *SqliteDb) void {
        if (self.handle) |h| {
            _ = c.sqlite3_close(h);
            self.handle = null;
        }
        self.allocator.destroy(self);
    }

    fn exec(self: *SqliteDb, sql: [*:0]const u8) !void {
        var err_msg: [*c]u8 = null;
        if (c.sqlite3_exec(self.handle, sql, null, null, &err_msg) != c.SQLITE_OK) {
            if (err_msg != null) c.sqlite3_free(err_msg);
            return error.SqliteExecFailed;
        }
    }

    fn initSchema(self: *SqliteDb) !void {
        try self.exec("PRAGMA journal_mode = WAL;");
        try self.exec("PRAGMA synchronous = NORMAL;");

        try self.exec(
            \\CREATE TABLE IF NOT EXISTS events (
            \\    seq INTEGER PRIMARY KEY,
            \\    node_id INTEGER,
            \\    event_code INTEGER,
            \\    ts INTEGER,
            \\    payload_len INTEGER,
            \\    prev_hash BLOB,
            \\    checksum BLOB,
            \\    payload TEXT
            \\);
            \\CREATE INDEX IF NOT EXISTS idx_events_ts ON events(ts);
            \\CREATE INDEX IF NOT EXISTS idx_events_code ON events(event_code);
            \\CREATE TABLE IF NOT EXISTS logs (
            \\    id INTEGER PRIMARY KEY AUTOINCREMENT,
            \\    ts INTEGER,
            \\    node TEXT,
            \\    level TEXT,
            \\    comp TEXT,
            \\    message TEXT
            \\);
            \\CREATE INDEX IF NOT EXISTS idx_logs_ts ON logs(ts DESC);
            \\CREATE VIRTUAL TABLE IF NOT EXISTS logs_fts USING fts5(node, level, comp, message);
            \\CREATE TABLE IF NOT EXISTS nodes (
            \\    name TEXT PRIMARY KEY,
            \\    role TEXT,
            \\    ip TEXT,
            \\    domain TEXT,
            \\    pubkey TEXT,
            \\    capabilities TEXT,
            \\    updated_at INTEGER
            \\);
            \\CREATE TABLE IF NOT EXISTS vms (
            \\    name TEXT PRIMARY KEY,
            \\    node TEXT,
            \\    vcpus INTEGER,
            \\    ram_mb INTEGER,
            \\    disk_gb INTEGER,
            \\    status TEXT,
            \\    ip TEXT,
            \\    updated_at INTEGER
            \\);
            \\CREATE TABLE IF NOT EXISTS gh_tokens (
            \\    slug TEXT PRIMARY KEY,
            \\    enc_token BLOB,
            \\    concurrency INTEGER,
            \\    active_jobs INTEGER DEFAULT 0,
            \\    cooldown_until INTEGER DEFAULT 0
            \\);
        );
    }

    pub fn insertEvent(self: *SqliteDb, seq: u64, node_id: u16, code: u16, ts: i64, payload_len: u32, prev_hash: *const [32]u8, checksum: *const [32]u8, payload: []const u8) !void {
        const query = "INSERT INTO events (seq, node_id, event_code, ts, payload_len, prev_hash, checksum, payload) VALUES (?, ?, ?, ?, ?, ?, ?, ?);";
        var stmt: ?*c.sqlite3_stmt = null;
        if (c.sqlite3_prepare_v2(self.handle, query, -1, &stmt, null) != c.SQLITE_OK) return error.PrepareFailed;
        defer _ = c.sqlite3_finalize(stmt);

        _ = c.sqlite3_bind_int64(stmt, 1, @intCast(seq));
        _ = c.sqlite3_bind_int(stmt, 2, node_id);
        _ = c.sqlite3_bind_int(stmt, 3, code);
        _ = c.sqlite3_bind_int64(stmt, 4, ts);
        _ = c.sqlite3_bind_int(stmt, 5, @intCast(payload_len));
        _ = c.sqlite3_bind_blob(stmt, 6, prev_hash, 32, c.SQLITE_STATIC);
        _ = c.sqlite3_bind_blob(stmt, 7, checksum, 32, c.SQLITE_STATIC);
        _ = c.sqlite3_bind_text(stmt, 8, payload.ptr, @intCast(payload.len), c.SQLITE_STATIC);

        if (c.sqlite3_step(stmt) != c.SQLITE_DONE) return error.StepFailed;
    }

    pub fn insertLog(self: *SqliteDb, ts: i64, node: []const u8, level: []const u8, comp: []const u8, message: []const u8) !void {
        const query_log = "INSERT INTO logs (ts, node, level, comp, message) VALUES (?, ?, ?, ?, ?);";
        var stmt_log: ?*c.sqlite3_stmt = null;
        if (c.sqlite3_prepare_v2(self.handle, query_log, -1, &stmt_log, null) != c.SQLITE_OK) return error.PrepareFailed;
        defer _ = c.sqlite3_finalize(stmt_log);

        _ = c.sqlite3_bind_int64(stmt_log, 1, ts);
        _ = c.sqlite3_bind_text(stmt_log, 2, node.ptr, @intCast(node.len), c.SQLITE_STATIC);
        _ = c.sqlite3_bind_text(stmt_log, 3, level.ptr, @intCast(level.len), c.SQLITE_STATIC);
        _ = c.sqlite3_bind_text(stmt_log, 4, comp.ptr, @intCast(comp.len), c.SQLITE_STATIC);
        _ = c.sqlite3_bind_text(stmt_log, 5, message.ptr, @intCast(message.len), c.SQLITE_STATIC);

        if (c.sqlite3_step(stmt_log) != c.SQLITE_DONE) return error.StepFailed;

        const query_fts = "INSERT INTO logs_fts (node, level, comp, message) VALUES (?, ?, ?, ?);";
        var stmt_fts: ?*c.sqlite3_stmt = null;
        if (c.sqlite3_prepare_v2(self.handle, query_fts, -1, &stmt_fts, null) != c.SQLITE_OK) return error.PrepareFailed;
        defer _ = c.sqlite3_finalize(stmt_fts);

        _ = c.sqlite3_bind_text(stmt_fts, 1, node.ptr, @intCast(node.len), c.SQLITE_STATIC);
        _ = c.sqlite3_bind_text(stmt_fts, 2, level.ptr, @intCast(level.len), c.SQLITE_STATIC);
        _ = c.sqlite3_bind_text(stmt_fts, 3, comp.ptr, @intCast(comp.len), c.SQLITE_STATIC);
        _ = c.sqlite3_bind_text(stmt_fts, 4, message.ptr, @intCast(message.len), c.SQLITE_STATIC);

        if (c.sqlite3_step(stmt_fts) != c.SQLITE_DONE) return error.StepFailed;
    }

    pub fn rotateLogs(self: *SqliteDb, retain_days: u32) !void {
        var buf: [128]u8 = undefined;
        const sql = try std.fmt.bufPrintZ(&buf, "DELETE FROM logs WHERE ts < (strftime('%s', 'now', '-{d} days') * 1000);", .{retain_days});
        try self.exec(sql.ptr);
    }
};
