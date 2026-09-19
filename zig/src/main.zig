const std = @import("std");
const config = @import("config.zig");
const edge = @import("edge/server.zig");
const ws = @import("ws/server.zig");
const db = @import("database/db.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var cfg = try config.Config.load(allocator);
    defer cfg.deinit(allocator);

    var database = db.Database.init(allocator, cfg.database_url);
    try database.execute("SELECT 1;");

    const edge_server = edge.EdgeServer.init(cfg.http_port, cfg.https_port);
    try edge_server.start();

    const ws_server = ws.WsServer.init(cfg.rpc_port);
    try ws_server.start();

    std.debug.print("Unsafie Cloud kernel initialized successfully\n", .{});
}
