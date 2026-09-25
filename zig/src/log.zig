const std = @import("std");
const builtin = @import("builtin");
const linux = std.os.linux;

pub const SpinLock = struct {
    state: std.atomic.Value(bool) = std.atomic.Value(bool).init(false),

    pub fn lock(self: *SpinLock) void {
        while (self.state.swap(true, .acquire)) {
            std.atomic.spinLoopHint();
        }
    }

    pub fn unlock(self: *SpinLock) void {
        self.state.store(false, .release);
    }
};

var log_lock: SpinLock = .{};

pub fn milliTimestamp() i64 {
    var ts: linux.timespec = undefined;
    _ = linux.clock_gettime(linux.CLOCK.REALTIME, &ts);
    return @as(i64, ts.sec) * 1000 + @divTrunc(ts.nsec, 1_000_000);
}

pub fn escapeJson(out: []u8, in: []const u8) []const u8 {
    var j: usize = 0;
    for (in) |c| {
        if (j + 2 >= out.len) break;
        switch (c) {
            '"' => {
                out[j] = '\\';
                out[j + 1] = '"';
                j += 2;
            },
            '\\' => {
                out[j] = '\\';
                out[j + 1] = '\\';
                j += 2;
            },
            '\n' => {
                out[j] = '\\';
                out[j + 1] = 'n';
                j += 2;
            },
            '\r' => {
                out[j] = '\\';
                out[j + 1] = 'r';
                j += 2;
            },
            '\t' => {
                out[j] = '\\';
                out[j + 1] = 't';
                j += 2;
            },
            else => {
                out[j] = c;
                j += 1;
            },
        }
    }
    return out[0..j];
}

pub fn formatJsonLog(out: []u8, ts: i64, level: []const u8, subsystem: []const u8, event: []const u8, message: []const u8) ?[]const u8 {
    var esc_buf: [1024]u8 = undefined;
    const esc_msg = escapeJson(&esc_buf, message);
    return std.fmt.bufPrint(
        out,
        "{{\"ts\":{d},\"level\":\"{s}\",\"subsystem\":\"{s}\",\"event\":\"{s}\",\"message\":\"{s}\"}}\n",
        .{ ts, level, subsystem, event, esc_msg },
    ) catch null;
}

pub fn jsonLog(level: []const u8, subsystem: []const u8, event: []const u8, message: []const u8) void {
    if (builtin.is_test) return;
    const ts = milliTimestamp();
    var line_buf: [2048]u8 = undefined;
    if (formatJsonLog(&line_buf, ts, level, subsystem, event, message)) |line| {
        log_lock.lock();
        defer log_lock.unlock();
        std.debug.print("{s}", .{line});
    }
}

pub fn jsonLogFmt(level: []const u8, subsystem: []const u8, event: []const u8, comptime fmt: []const u8, args: anytype) void {
    if (builtin.is_test) return;
    var raw_buf: [1024]u8 = undefined;
    const raw_msg = std.fmt.bufPrint(&raw_buf, fmt, args) catch "format_error";
    jsonLog(level, subsystem, event, raw_msg);
}

pub fn info(subsystem: []const u8, event: []const u8, message: []const u8) void {
    jsonLog("INFO", subsystem, event, message);
}

pub fn infoFmt(subsystem: []const u8, event: []const u8, comptime fmt: []const u8, args: anytype) void {
    jsonLogFmt("INFO", subsystem, event, fmt, args);
}

pub fn warn(subsystem: []const u8, event: []const u8, message: []const u8) void {
    jsonLog("WARN", subsystem, event, message);
}

pub fn warnFmt(subsystem: []const u8, event: []const u8, comptime fmt: []const u8, args: anytype) void {
    jsonLogFmt("WARN", subsystem, event, fmt, args);
}

pub fn err(subsystem: []const u8, event: []const u8, message: []const u8) void {
    jsonLog("ERROR", subsystem, event, message);
}

pub fn errFmt(subsystem: []const u8, event: []const u8, comptime fmt: []const u8, args: anytype) void {
    jsonLogFmt("ERROR", subsystem, event, fmt, args);
}

pub fn debug(subsystem: []const u8, event: []const u8, message: []const u8) void {
    jsonLog("DEBUG", subsystem, event, message);
}

pub fn debugFmt(subsystem: []const u8, event: []const u8, comptime fmt: []const u8, args: anytype) void {
    jsonLogFmt("DEBUG", subsystem, event, fmt, args);
}
