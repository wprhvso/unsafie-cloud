const std = @import("std");

pub const TimingWheel = struct {
    pub const SlotCount: usize = 1024;

    current_tick: u64 = 0,
    slots: [SlotCount]std.ArrayList(u32),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) TimingWheel {
        var tw = TimingWheel{
            .current_tick = 0,
            .slots = undefined,
            .allocator = allocator,
        };
        for (0..SlotCount) |i| {
            tw.slots[i] = std.ArrayList(u32){};
        }
        return tw;
    }

    pub fn deinit(self: *TimingWheel) void {
        for (0..SlotCount) |i| {
            self.slots[i].deinit(self.allocator);
        }
    }

    pub fn schedule(self: *TimingWheel, event_id: u32, delay_ticks: u64) !void {
        const target_tick = self.current_tick + delay_ticks;
        const slot_idx = target_tick % SlotCount;
        try self.slots[slot_idx].append(self.allocator, event_id);
    }

    pub fn tick(self: *TimingWheel, out_events: *std.ArrayList(u32)) !void {
        const slot_idx = self.current_tick % SlotCount;
        if (self.slots[slot_idx].items.len > 0) {
            try out_events.appendSlice(self.allocator, self.slots[slot_idx].items);
            self.slots[slot_idx].clearRetainingCapacity();
        }
        self.current_tick += 1;
    }
};
