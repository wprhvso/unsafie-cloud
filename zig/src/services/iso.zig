const std = @import("std");

pub const IsoService = struct {
    pub fn downloadIso(url: []const u8, name: []const u8) !void {
        _ = url;
        _ = name;
    }
};
