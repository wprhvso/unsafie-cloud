const std = @import("std");
const event = @import("event.zig");
const wal = @import("wal.zig");
const reducer = @import("reducer.zig");

pub const LedgerEngine = struct {
    allocator: std.mem.Allocator,
    node_id: u16,
    wal_engine: wal.WalEngine,
    state_reducer: reducer.EventReducer,

    pub fn init(allocator: std.mem.Allocator, node_id: u16, data_dir: []const u8) !*LedgerEngine {
        const self = try allocator.create(LedgerEngine);
        errdefer allocator.destroy(self);

        self.allocator = allocator;
        self.node_id = node_id;
        self.wal_engine = try wal.WalEngine.init(allocator, data_dir);
        self.state_reducer = reducer.EventReducer.init(allocator);

        return self;
    }

    pub fn deinit(self: *LedgerEngine) void {
        self.wal_engine.deinit();
        self.state_reducer.deinit();
        self.allocator.destroy(self);
    }

    pub fn emit(self: *LedgerEngine, code: event.EventCode, payload: []const u8) !event.EventHeader {
        const hdr = try self.wal_engine.append(self.node_id, @intFromEnum(code), payload);
        try self.state_reducer.apply(@intFromEnum(code), payload);
        return hdr;
    }

    pub fn getStatus(self: *LedgerEngine) ![]const u8 {
        var buf: [256]u8 = undefined;
        return std.fmt.bufPrint(&buf, "{{\"last_seq\":{d},\"nodes\":{d},\"vms\":{d}}}", .{
            self.wal_engine.last_seq,
            self.state_reducer.nodes.count(),
            self.state_reducer.vms.count(),
        });
    }
};
