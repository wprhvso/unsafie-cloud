const std = @import("std");
const event = @import("event.zig");

pub const WalEngine = struct {
    allocator: std.mem.Allocator,
    dir_path: []const u8,
    file: ?std.fs.File = null,
    last_seq: u64 = 0,
    last_hash: [32]u8 = [_]u8{0} ** 32,

    pub fn init(allocator: std.mem.Allocator, dir_path: []const u8) !WalEngine {
        std.fs.cwd().makePath(dir_path) catch {};
        const full_file_path = try std.fs.path.join(allocator, &[_][]const u8{ dir_path, "events.wal" });
        defer allocator.free(full_file_path);

        const file = std.fs.cwd().openFile(full_file_path, .{ .mode = .read_write }) catch |err| switch (err) {
            error.FileNotFound => try std.fs.cwd().createFile(full_file_path, .{ .read = true }),
            else => return err,
        };

        var wal = WalEngine{
            .allocator = allocator,
            .dir_path = try allocator.dupe(u8, dir_path),
            .file = file,
            .last_seq = 0,
            .last_hash = [_]u8{0} ** 32,
        };

        try wal.recoverLastState();
        return wal;
    }

    pub fn deinit(self: *WalEngine) void {
        if (self.file) |f| {
            f.close();
            self.file = null;
        }
        self.allocator.free(self.dir_path);
    }

    fn recoverLastState(self: *WalEngine) !void {
        const file = self.file orelse return;
        const end_pos = try file.getEndPos();
        if (end_pos == 0) return;

        try file.seekTo(0);
        var buf: [96]u8 = undefined;
        while (true) {
            const bytes_read = file.read(&buf) catch break;
            if (bytes_read < 96) break;

            const hdr: *const event.EventHeader = @ptrCast(@alignCast(&buf));
            if (hdr.magic != event.Magic) break;

            self.last_seq = hdr.seq;
            self.last_hash = hdr.checksum;

            try file.seekBy(@intCast(hdr.payload_len));
        }
        try file.seekFromEnd(0);
    }

    pub fn append(self: *WalEngine, node_id: u16, event_code: u16, payload: []const u8) !event.EventHeader {
        const file = self.file orelse return error.FileNotFound;

        const seq = self.last_seq + 1;
        const ts = std.time.milliTimestamp();
        const payload_len: u32 = @intCast(payload.len);

        const checksum = event.EventHeader.computeHash(
            node_id,
            event_code,
            seq,
            ts,
            payload_len,
            self.last_hash,
            payload,
        );

        const hdr = event.EventHeader{
            .magic = event.Magic,
            .node_id = node_id,
            .event_code = event_code,
            .seq = seq,
            .ts = ts,
            .payload_len = payload_len,
            .flags = 0,
            .reserved = 0,
            .prev_hash = self.last_hash,
            .checksum = checksum,
        };

        const hdr_bytes: *const [96]u8 = @ptrCast(&hdr);
        _ = try file.write(hdr_bytes);
        if (payload.len > 0) {
            _ = try file.write(payload);
        }

        self.last_seq = seq;
        self.last_hash = checksum;

        return hdr;
    }
};
