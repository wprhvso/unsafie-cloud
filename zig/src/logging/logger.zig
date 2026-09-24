const std = @import("std");
const db_mod = @import("../db/sqlite.zig");

pub const LogLevel = enum {
    debug,
    info,
    warn,
    err,

    pub fn asString(self: LogLevel) []const u8 {
        return switch (self) {
            .debug => "DEBUG",
            .info => "INFO",
            .warn => "WARN",
            .err => "ERROR",
        };
    }
};

pub const StructuredLogger = struct {
    allocator: std.mem.Allocator,
    node_name: []const u8 = "node1",
    db: ?*db_mod.SqliteDb = null,
    mutex: std.Thread.Mutex = .{},

    pub fn init(allocator: std.mem.Allocator, node_name: []const u8, db: ?*db_mod.SqliteDb) StructuredLogger {
        return .{
            .allocator = allocator,
            .node_name = node_name,
            .db = db,
            .mutex = .{},
        };
    }

    pub fn logTraffic(
        self: *StructuredLogger,
        direction: []const u8,
        src_ip: []const u8,
        src_port: u16,
        dst_ip: []const u8,
        dst_port: u16,
        protocol: []const u8,
        action: []const u8,
        reason: []const u8,
        size: u32,
        iface: []const u8,
    ) void {
        const database = self.db orelse return;
        self.mutex.lock();
        defer self.mutex.unlock();

        const now = std.time.milliTimestamp();
        var iso_buf = [_]u8{0} ** 32;
        const now_s: u64 = @intCast(@divTrunc(now, 1000));
        const iso = std.fmt.bufPrint(&iso_buf, "{d}-epoch-ms", .{now_s}) catch "";

        database.insertDetailed(.{
            .ts = now,
            .timestamp_iso = iso,
            .node_name = self.node_name,
            .level = "INFO",
            .subsystem = "router",
            .event_type = "packet_routed",
            .direction = direction,
            .src_ip = src_ip,
            .src_port = src_port,
            .dst_ip = dst_ip,
            .dst_port = dst_port,
            .protocol = protocol,
            .route_action = action,
            .route_reason = reason,
            .packet_size_bytes = size,
            .interface_name = iface,
            .message = "Packet evaluated by L3 router",
        }) catch {};
    }

    pub fn logDns(
        self: *StructuredLogger,
        domain: []const u8,
        qtype: []const u8,
        is_domestic: bool,
        resolved_ips: ?[]const u8,
    ) void {
        const database = self.db orelse return;
        self.mutex.lock();
        defer self.mutex.unlock();

        const now = std.time.milliTimestamp();
        var iso_buf = [_]u8{0} ** 32;
        const now_s: u64 = @intCast(@divTrunc(now, 1000));
        const iso = std.fmt.bufPrint(&iso_buf, "{d}-epoch-ms", .{now_s}) catch "";

        database.insertDetailed(.{
            .ts = now,
            .timestamp_iso = iso,
            .node_name = self.node_name,
            .level = "INFO",
            .subsystem = "dns",
            .event_type = if (is_domestic) "dns_domestic" else "dns_overseas",
            .domain = domain,
            .qtype = qtype,
            .resolved_ips = resolved_ips,
            .route_action = if (is_domestic) "direct_bypass" else "tunnel_exit",
            .route_reason = if (is_domestic) "domestic_domain" else "foreign_domain",
            .message = if (is_domestic) "Resolved domestic domain via direct DNS" else "Resolved foreign domain via tunnel DNS",
        }) catch {};
    }

    pub fn logSystem(self: *StructuredLogger, level: []const u8, subsystem: []const u8, event_type: []const u8, message: []const u8) void {
        const database = self.db orelse return;
        self.mutex.lock();
        defer self.mutex.unlock();

        const now = std.time.milliTimestamp();
        var iso_buf = [_]u8{0} ** 32;
        const now_s: u64 = @intCast(@divTrunc(now, 1000));
        const iso = std.fmt.bufPrint(&iso_buf, "{d}-epoch-ms", .{now_s}) catch "";

        database.insertDetailed(.{
            .ts = now,
            .timestamp_iso = iso,
            .node_name = self.node_name,
            .level = level,
            .subsystem = subsystem,
            .event_type = event_type,
            .message = message,
        }) catch {};
    }
};
