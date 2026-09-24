const std = @import("std");
const client = @import("../client.zig");
const db_mod = @import("../../db/sqlite.zig");
const config = @import("../../config.zig");

pub fn execute(cl: client.Client, args: []const []const u8) !void {
    var limit: usize = 100;
    var filter_level: ?[]const u8 = null;

    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        if (std.mem.eql(u8, arg, "--limit") or std.mem.eql(u8, arg, "-n")) {
            if (i + 1 < args.len) {
                i += 1;
                limit = std.fmt.parseInt(usize, args[i], 10) catch 100;
            }
        } else if (std.mem.eql(u8, arg, "--level") or std.mem.eql(u8, arg, "-l")) {
            if (i + 1 < args.len) {
                i += 1;
                filter_level = args[i];
            }
        }
    }

    var cfg = config.Config.load(cl.allocator) catch {
        return;
    };
    defer cfg.deinit(cl.allocator);

    const db_file_path = std.fs.path.join(cl.allocator, &[_][]const u8{ cfg.state_dir, "unsafie.db" }) catch {
        return;
    };
    defer cl.allocator.free(db_file_path);

    var db = db_mod.SqliteDb.init(cl.allocator, db_file_path) catch {
        std.debug.print("[]\n", .{});
        return;
    };
    defer db.deinit();

    const json_logs = db.queryJsonLogs(cl.allocator, limit, filter_level) catch {
        std.debug.print("[]\n", .{});
        return;
    };
    defer {
        for (json_logs) |line| cl.allocator.free(line);
        cl.allocator.free(json_logs);
    }

    for (json_logs) |line| {
        std.debug.print("{s}\n", .{line});
    }
}
