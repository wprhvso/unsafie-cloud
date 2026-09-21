const std = @import("std");
const git_state = @import("../state/git.zig");

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

pub const LogEntry = struct {
    ts: i64,
    lvl: []const u8,
    node: []const u8,
    comp: []const u8,
    msg: []const u8,
};

pub const JsonLogger = struct {
    allocator: std.mem.Allocator,
    node_name: []const u8,
    log_dir: []const u8,
    git_store: ?*git_state.GitStore = null,
    history: std.ArrayList(LogEntry),
    pending_lines: std.ArrayList(u8),
    last_flush: i64 = 0,

    pub fn init(allocator: std.mem.Allocator, node_name: []const u8, log_dir: []const u8, git_store: ?*git_state.GitStore) JsonLogger {
        return .{
            .allocator = allocator,
            .node_name = node_name,
            .log_dir = log_dir,
            .git_store = git_store,
            .history = std.ArrayList(LogEntry){},
            .pending_lines = std.ArrayList(u8){},
            .last_flush = std.time.timestamp(),
        };
    }

    pub fn deinit(self: *JsonLogger) void {
        for (self.history.items) |entry| {
            self.allocator.free(entry.msg);
        }
        self.history.deinit(self.allocator);
        self.pending_lines.deinit(self.allocator);
    }

    pub fn log(self: *JsonLogger, level: LogLevel, comp: []const u8, msg: []const u8) !void {
        const now = std.time.milliTimestamp();

        var buf: [512]u8 = undefined;
        const line = try std.fmt.bufPrint(&buf, "{{\"ts\":{d},\"lvl\":\"{s}\",\"node\":\"{s}\",\"comp\":\"{s}\",\"msg\":\"{s}\"}}\n", .{
            now,
            level.asString(),
            self.node_name,
            comp,
            msg,
        });

        std.fs.cwd().makePath(self.log_dir) catch {};

        const log_file_path = try std.fs.path.join(self.allocator, &[_][]const u8{ self.log_dir, "cluster.jsonl" });
        defer self.allocator.free(log_file_path);

        const file = std.fs.cwd().openFile(log_file_path, .{ .mode = .read_write }) catch |err| switch (err) {
            error.FileNotFound => try std.fs.cwd().createFile(log_file_path, .{}),
            else => return err,
        };
        defer file.close();
        try file.seekFromEnd(0);
        _ = try file.write(line);

        const msg_copy = try self.allocator.dupe(u8, msg);
        if (self.history.items.len >= 500) {
            const old = self.history.orderedRemove(0);
            self.allocator.free(old.msg);
        }
        try self.history.append(self.allocator, .{
            .ts = now,
            .lvl = level.asString(),
            .node = self.node_name,
            .comp = comp,
            .msg = msg_copy,
        });

        try self.pending_lines.appendSlice(self.allocator, line);

        const cur_sec = std.time.timestamp();
        if (cur_sec - self.last_flush >= 2 and self.pending_lines.items.len > 0) {
            self.flushToGit();
        }
    }

    fn flushToGit(self: *JsonLogger) void {
        if (self.git_store) |gs| {
            const rel_path = "logs/cluster.jsonl";
            gs.commitFile(rel_path, self.pending_lines.items, "log(cluster): batch flush") catch {};
        }
        self.pending_lines.clearRetainingCapacity();
        self.last_flush = std.time.timestamp();
    }

    pub fn getRecent(self: *JsonLogger) []const LogEntry {
        return self.history.items;
    }
};
