const std = @import("std");

pub const BbrState = enum {
    startup,
    drain,
    probe_bw,
    probe_rtt,
};

pub const BbrController = struct {
    state: BbrState = .startup,
    btlbw: u64 = 1_000_000,
    rtprop_us: u64 = 20_000,
    pacing_gain: f32 = 2.885,
    pacing_rate: u64 = 2_885_000,
    round_count: u32 = 0,

    pub fn init() BbrController {
        var b = BbrController{};
        b.updatePacingRate();
        return b;
    }

    pub fn updatePacingRate(self: *BbrController) void {
        const rate_float = @as(f32, @floatFromInt(self.btlbw)) * self.pacing_gain;
        self.pacing_rate = @intFromFloat(@max(rate_float, 64_000.0));
    }

    pub fn getPacketIntervalNs(self: *BbrController, packet_size: usize) u64 {
        if (self.pacing_rate == 0) return 0;
        const total_ns = @as(u128, packet_size) * 1_000_000_000;
        return @intCast(total_ns / self.pacing_rate);
    }

    pub fn onAck(self: *BbrController, delivered_bytes: u64, rtt_us: u64) void {
        if (rtt_us > 0 and rtt_us < self.rtprop_us) {
            self.rtprop_us = rtt_us;
        }

        if (rtt_us > 0) {
            const sample_bw = (delivered_bytes * 1_000_000) / rtt_us;
            if (sample_bw > self.btlbw) {
                self.btlbw = sample_bw;
            }
        }

        self.round_count += 1;
        switch (self.state) {
            .startup => {
                if (self.round_count > 3) {
                    self.state = .drain;
                    self.pacing_gain = 0.35;
                }
            },
            .drain => {
                if (self.round_count > 5) {
                    self.state = .probe_bw;
                    self.pacing_gain = 1.0;
                }
            },
            .probe_bw => {
                const cycle = self.round_count % 8;
                if (cycle == 0) {
                    self.pacing_gain = 1.25;
                } else if (cycle == 1) {
                    self.pacing_gain = 0.75;
                } else {
                    self.pacing_gain = 1.0;
                }
            },
            .probe_rtt => {
                self.pacing_gain = 1.0;
            },
        }

        self.updatePacingRate();
    }
};
