const std = @import("std");

const c = @cImport({
    @cInclude("sqlite3.h");
});

pub const DetailedLog = struct {
    ts: i64 = 0,
    timestamp_iso: []const u8 = "",
    node_name: []const u8 = "node1",
    node_role: []const u8 = "node",
    cluster_id: []const u8 = "default",
    session_id: ?[]const u8 = null,
    connection_id: ?[]const u8 = null,
    trace_id: ?[]const u8 = null,
    level: []const u8 = "INFO",
    subsystem: []const u8 = "system",
    event_type: []const u8 = "generic",
    direction: ?[]const u8 = null,
    src_ip: ?[]const u8 = null,
    src_port: ?u16 = null,
    dst_ip: ?[]const u8 = null,
    dst_port: ?u16 = null,
    protocol: ?[]const u8 = null,
    domain: ?[]const u8 = null,
    qtype: ?[]const u8 = null,
    rcode: ?[]const u8 = null,
    resolved_ips: ?[]const u8 = null,
    route_action: ?[]const u8 = null,
    route_reason: ?[]const u8 = null,
    packet_size_bytes: ?u32 = null,
    bytes_sent: u64 = 0,
    bytes_received: u64 = 0,
    duration_ms: ?f64 = null,
    cipher_suite: ?[]const u8 = null,
    alpn: ?[]const u8 = null,
    tls_fingerprint: ?[]const u8 = null,
    client_platform: ?[]const u8 = null,
    client_version: ?[]const u8 = null,
    interface_name: ?[]const u8 = null,
    uplink_gateway: ?[]const u8 = null,
    message: []const u8 = "",
    error_code: ?[]const u8 = null,
    error_details: ?[]const u8 = null,
    metadata_json: []const u8 = "{}",

    pub fn toJsonString(self: DetailedLog, allocator: std.mem.Allocator) ![]const u8 {
        var buf = std.ArrayList(u8){};
        errdefer buf.deinit(allocator);

        var writer = buf.writer(allocator);
        try writer.print(
            "{{\"ts\":{d},\"timestamp_iso\":\"{s}\",\"node\":\"{s}\",\"role\":\"{s}\",\"level\":\"{s}\",\"subsystem\":\"{s}\",\"event\":\"{s}\",\"message\":\"{s}\"",
            .{
                self.ts,
                self.timestamp_iso,
                self.node_name,
                self.node_role,
                self.level,
                self.subsystem,
                self.event_type,
                self.message,
            },
        );

        if (self.src_ip) |s| try writer.print(",\"src_ip\":\"{s}\"", .{s});
        if (self.src_port) |sp| try writer.print(",\"src_port\":{d}", .{sp});
        if (self.dst_ip) |d| try writer.print(",\"dst_ip\":\"{s}\"", .{d});
        if (self.dst_port) |dp| try writer.print(",\"dst_port\":{d}", .{dp});
        if (self.protocol) |pr| try writer.print(",\"protocol\":\"{s}\"", .{pr});
        if (self.domain) |dm| try writer.print(",\"domain\":\"{s}\"", .{dm});
        if (self.resolved_ips) |res| try writer.print(",\"resolved_ips\":\"{s}\"", .{res});
        if (self.route_action) |act| try writer.print(",\"route_action\":\"{s}\"", .{act});
        if (self.route_reason) |rsn| try writer.print(",\"route_reason\":\"{s}\"", .{rsn});
        if (self.packet_size_bytes) |ps| try writer.print(",\"size\":{d}", .{ps});
        if (self.interface_name) |ifn| try writer.print(",\"iface\":\"{s}\"", .{ifn});
        if (self.cipher_suite) |cs| try writer.print(",\"cipher\":\"{s}\"", .{cs});
        if (self.error_code) |ec| try writer.print(",\"error\":\"{s}\"", .{ec});

        try writer.writeAll("}");
        return try buf.toOwnedSlice(allocator);
    }
};

pub const SqliteDb = struct {
    allocator: std.mem.Allocator,
    handle: ?*c.sqlite3,

    pub fn init(allocator: std.mem.Allocator, path: []const u8) !*SqliteDb {
        const self = try allocator.create(SqliteDb);
        errdefer allocator.destroy(self);

        self.allocator = allocator;

        if (std.fs.path.dirname(path)) |parent| {
            std.fs.cwd().makePath(parent) catch {};
        }

        const path_z = try allocator.dupeZ(u8, path);
        defer allocator.free(path_z);

        var db: ?*c.sqlite3 = null;
        if (c.sqlite3_open(path_z, &db) != c.SQLITE_OK) {
            if (db) |d| _ = c.sqlite3_close(d);
            db = null;

            std.fs.cwd().makePath("/tmp/unsafie") catch {};
            if (c.sqlite3_open("/tmp/unsafie/unsafie.db", &db) != c.SQLITE_OK) {
                if (db) |d| _ = c.sqlite3_close(d);
                db = null;

                if (c.sqlite3_open(":memory:", &db) != c.SQLITE_OK) {
                    return error.SqliteOpenFailed;
                }
            }
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

        try self.exec("CREATE TABLE IF NOT EXISTS cluster_logs (" ++
            "id INTEGER PRIMARY KEY AUTOINCREMENT," ++
            "ts INTEGER NOT NULL," ++
            "timestamp_iso TEXT NOT NULL," ++
            "node_name TEXT NOT NULL," ++
            "node_role TEXT NOT NULL DEFAULT 'node'," ++
            "cluster_id TEXT DEFAULT 'default'," ++
            "session_id TEXT," ++
            "connection_id TEXT," ++
            "trace_id TEXT," ++
            "level TEXT NOT NULL DEFAULT 'INFO'," ++
            "subsystem TEXT NOT NULL," ++
            "event_type TEXT NOT NULL," ++
            "direction TEXT," ++
            "src_ip TEXT," ++
            "src_port INTEGER," ++
            "dst_ip TEXT," ++
            "dst_port INTEGER," ++
            "protocol TEXT," ++
            "domain TEXT," ++
            "qtype TEXT," ++
            "rcode TEXT," ++
            "resolved_ips TEXT," ++
            "route_action TEXT," ++
            "route_reason TEXT," ++
            "packet_size_bytes INTEGER," ++
            "bytes_sent INTEGER DEFAULT 0," ++
            "bytes_received INTEGER DEFAULT 0," ++
            "duration_ms REAL," ++
            "cipher_suite TEXT," ++
            "alpn TEXT," ++
            "tls_fingerprint TEXT," ++
            "client_platform TEXT," ++
            "client_version TEXT," ++
            "interface_name TEXT," ++
            "uplink_gateway TEXT," ++
            "message TEXT NOT NULL," ++
            "error_code TEXT," ++
            "error_details TEXT," ++
            "metadata_json TEXT DEFAULT '{}');");

        try self.exec("CREATE INDEX IF NOT EXISTS idx_cluster_logs_ts ON cluster_logs(ts DESC);");
        try self.exec("CREATE INDEX IF NOT EXISTS idx_cluster_logs_node ON cluster_logs(node_name, ts DESC);");
        try self.exec("CREATE INDEX IF NOT EXISTS idx_cluster_logs_subsystem_event ON cluster_logs(subsystem, event_type, ts DESC);");
        try self.exec("CREATE INDEX IF NOT EXISTS idx_cluster_logs_level ON cluster_logs(level);");
        try self.exec("CREATE INDEX IF NOT EXISTS idx_cluster_logs_route_action ON cluster_logs(route_action, ts DESC);");
        try self.exec("CREATE INDEX IF NOT EXISTS idx_cluster_logs_domain ON cluster_logs(domain);");
        try self.exec("CREATE INDEX IF NOT EXISTS idx_cluster_logs_src_dst ON cluster_logs(src_ip, dst_ip);");
    }

    pub fn insertDetailed(self: *SqliteDb, l: DetailedLog) !void {
        const sql = "INSERT INTO cluster_logs (ts, timestamp_iso, node_name, node_role, cluster_id, session_id, connection_id, trace_id, level, subsystem, event_type, direction, src_ip, src_port, dst_ip, dst_port, protocol, domain, qtype, rcode, resolved_ips, route_action, route_reason, packet_size_bytes, bytes_sent, bytes_received, duration_ms, cipher_suite, alpn, tls_fingerprint, client_platform, client_version, interface_name, uplink_gateway, message, error_code, error_details, metadata_json) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);";

        var stmt: ?*c.sqlite3_stmt = null;
        if (c.sqlite3_prepare_v2(self.handle, sql, -1, &stmt, null) != c.SQLITE_OK) return error.PrepareFailed;
        defer _ = c.sqlite3_finalize(stmt);

        _ = c.sqlite3_bind_int64(stmt, 1, l.ts);
        _ = c.sqlite3_bind_text(stmt, 2, l.timestamp_iso.ptr, @intCast(l.timestamp_iso.len), c.SQLITE_STATIC);
        _ = c.sqlite3_bind_text(stmt, 3, l.node_name.ptr, @intCast(l.node_name.len), c.SQLITE_STATIC);
        _ = c.sqlite3_bind_text(stmt, 4, l.node_role.ptr, @intCast(l.node_role.len), c.SQLITE_STATIC);
        _ = c.sqlite3_bind_text(stmt, 5, l.cluster_id.ptr, @intCast(l.cluster_id.len), c.SQLITE_STATIC);
        bindNullableText(stmt, 6, l.session_id);
        bindNullableText(stmt, 7, l.connection_id);
        bindNullableText(stmt, 8, l.trace_id);
        _ = c.sqlite3_bind_text(stmt, 9, l.level.ptr, @intCast(l.level.len), c.SQLITE_STATIC);
        _ = c.sqlite3_bind_text(stmt, 10, l.subsystem.ptr, @intCast(l.subsystem.len), c.SQLITE_STATIC);
        _ = c.sqlite3_bind_text(stmt, 11, l.event_type.ptr, @intCast(l.event_type.len), c.SQLITE_STATIC);
        bindNullableText(stmt, 12, l.direction);
        bindNullableText(stmt, 13, l.src_ip);
        bindNullableInt(stmt, 14, l.src_port);
        bindNullableText(stmt, 15, l.dst_ip);
        bindNullableInt(stmt, 16, l.dst_port);
        bindNullableText(stmt, 17, l.protocol);
        bindNullableText(stmt, 18, l.domain);
        bindNullableText(stmt, 19, l.qtype);
        bindNullableText(stmt, 20, l.rcode);
        bindNullableText(stmt, 21, l.resolved_ips);
        bindNullableText(stmt, 22, l.route_action);
        bindNullableText(stmt, 23, l.route_reason);
        bindNullableInt(stmt, 24, l.packet_size_bytes);
        _ = c.sqlite3_bind_int64(stmt, 25, @intCast(l.bytes_sent));
        _ = c.sqlite3_bind_int64(stmt, 26, @intCast(l.bytes_received));
        bindNullableDouble(stmt, 27, l.duration_ms);
        bindNullableText(stmt, 28, l.cipher_suite);
        bindNullableText(stmt, 29, l.alpn);
        bindNullableText(stmt, 30, l.tls_fingerprint);
        bindNullableText(stmt, 31, l.client_platform);
        bindNullableText(stmt, 32, l.client_version);
        bindNullableText(stmt, 33, l.interface_name);
        bindNullableText(stmt, 34, l.uplink_gateway);
        _ = c.sqlite3_bind_text(stmt, 35, l.message.ptr, @intCast(l.message.len), c.SQLITE_STATIC);
        bindNullableText(stmt, 36, l.error_code);
        bindNullableText(stmt, 37, l.error_details);
        _ = c.sqlite3_bind_text(stmt, 38, l.metadata_json.ptr, @intCast(l.metadata_json.len), c.SQLITE_STATIC);

        if (c.sqlite3_step(stmt) != c.SQLITE_DONE) return error.StepFailed;
    }

    fn bindNullableText(stmt: ?*c.sqlite3_stmt, col: c_int, text: ?[]const u8) void {
        if (text) |t| {
            _ = c.sqlite3_bind_text(stmt, col, t.ptr, @intCast(t.len), c.SQLITE_STATIC);
        } else {
            _ = c.sqlite3_bind_null(stmt, col);
        }
    }

    fn bindNullableInt(stmt: ?*c.sqlite3_stmt, col: c_int, val: anytype) void {
        if (val) |v| {
            _ = c.sqlite3_bind_int(stmt, col, @intCast(v));
        } else {
            _ = c.sqlite3_bind_null(stmt, col);
        }
    }

    fn bindNullableDouble(stmt: ?*c.sqlite3_stmt, col: c_int, val: ?f64) void {
        if (val) |v| {
            _ = c.sqlite3_bind_double(stmt, col, v);
        } else {
            _ = c.sqlite3_bind_null(stmt, col);
        }
    }

    pub fn insertLog(self: *SqliteDb, ts: i64, node: []const u8, level: []const u8, comp: []const u8, message: []const u8) !void {
        var iso_buf = [_]u8{0} ** 32;
        const now_s: u64 = @intCast(@divTrunc(ts, 1000));
        const iso = try std.fmt.bufPrint(&iso_buf, "{d}-epoch-ms", .{now_s});

        try self.insertDetailed(.{
            .ts = ts,
            .timestamp_iso = iso,
            .node_name = node,
            .level = level,
            .subsystem = comp,
            .event_type = "system",
            .message = message,
        });
    }

    pub fn queryJsonLogs(self: *SqliteDb, allocator: std.mem.Allocator, limit: usize, filter_level: ?[]const u8) ![]const []const u8 {
        var list = std.ArrayList([]const u8){};
        errdefer {
            for (list.items) |it| allocator.free(it);
            list.deinit(allocator);
        }

        const sql = if (filter_level != null)
            "SELECT ts, timestamp_iso, node_name, node_role, level, subsystem, event_type, src_ip, src_port, dst_ip, dst_port, protocol, domain, resolved_ips, route_action, packet_size_bytes, interface_name, cipher_suite, message, error_code FROM cluster_logs WHERE level = ? ORDER BY id DESC LIMIT ?;"
        else
            "SELECT ts, timestamp_iso, node_name, node_role, level, subsystem, event_type, src_ip, src_port, dst_ip, dst_port, protocol, domain, resolved_ips, route_action, packet_size_bytes, interface_name, cipher_suite, message, error_code FROM cluster_logs ORDER BY id DESC LIMIT ?;";

        var stmt: ?*c.sqlite3_stmt = null;
        if (c.sqlite3_prepare_v2(self.handle, sql, -1, &stmt, null) != c.SQLITE_OK) return error.PrepareFailed;
        defer _ = c.sqlite3_finalize(stmt);

        var param_idx: c_int = 1;
        if (filter_level) |fl| {
            _ = c.sqlite3_bind_text(stmt, param_idx, fl.ptr, @intCast(fl.len), c.SQLITE_STATIC);
            param_idx += 1;
        }
        _ = c.sqlite3_bind_int(stmt, param_idx, @intCast(limit));

        while (c.sqlite3_step(stmt) == c.SQLITE_ROW) {
            const entry = DetailedLog{
                .ts = c.sqlite3_column_int64(stmt, 0),
                .timestamp_iso = getColText(stmt, 1),
                .node_name = getColText(stmt, 2),
                .node_role = getColText(stmt, 3),
                .level = getColText(stmt, 4),
                .subsystem = getColText(stmt, 5),
                .event_type = getColText(stmt, 6),
                .src_ip = getNullableColText(stmt, 7),
                .src_port = getNullableColInt(stmt, 8),
                .dst_ip = getNullableColText(stmt, 9),
                .dst_port = getNullableColInt(stmt, 10),
                .protocol = getNullableColText(stmt, 11),
                .domain = getNullableColText(stmt, 12),
                .resolved_ips = getNullableColText(stmt, 13),
                .route_action = getNullableColText(stmt, 14),
                .packet_size_bytes = getNullableColInt32(stmt, 15),
                .interface_name = getNullableColText(stmt, 16),
                .cipher_suite = getNullableColText(stmt, 17),
                .message = getColText(stmt, 18),
                .error_code = getNullableColText(stmt, 19),
            };

            const json = try entry.toJsonString(allocator);
            try list.append(allocator, json);
        }

        return try list.toOwnedSlice(allocator);
    }

    fn getColText(stmt: ?*c.sqlite3_stmt, col: c_int) []const u8 {
        const ptr = c.sqlite3_column_text(stmt, col);
        if (ptr == null) return "";
        const len = c.sqlite3_column_bytes(stmt, col);
        return ptr[0..@intCast(len)];
    }

    fn getNullableColText(stmt: ?*c.sqlite3_stmt, col: c_int) ?[]const u8 {
        if (c.sqlite3_column_type(stmt, col) == c.SQLITE_NULL) return null;
        const ptr = c.sqlite3_column_text(stmt, col);
        if (ptr == null) return null;
        const len = c.sqlite3_column_bytes(stmt, col);
        return ptr[0..@intCast(len)];
    }

    fn getNullableColInt(stmt: ?*c.sqlite3_stmt, col: c_int) ?u16 {
        if (c.sqlite3_column_type(stmt, col) == c.SQLITE_NULL) return null;
        return @intCast(c.sqlite3_column_int(stmt, col));
    }

    fn getNullableColInt32(stmt: ?*c.sqlite3_stmt, col: c_int) ?u32 {
        if (c.sqlite3_column_type(stmt, col) == c.SQLITE_NULL) return null;
        return @intCast(c.sqlite3_column_int(stmt, col));
    }
};

test "detailed log to json string" {
    const log_entry = DetailedLog{
        .ts = 1727145600000,
        .timestamp_iso = "2026-09-24T02:00:00Z",
        .node_name = "test-node",
        .level = "INFO",
        .subsystem = "router",
        .event_type = "packet_routed",
        .src_ip = "10.42.0.2",
        .dst_ip = "1.1.1.1",
        .route_action = "tunnel_exit",
        .message = "Routed to VPS",
    };

    const json = try log_entry.toJsonString(std.testing.allocator);
    defer std.testing.allocator.free(json);

    try std.testing.expect(std.mem.indexOf(u8, json, "\"route_action\":\"tunnel_exit\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"src_ip\":\"10.42.0.2\"") != null);
}
