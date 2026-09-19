const std = @import("std");

pub const IsoEnsureParams = struct {
    name: []const u8,
    url: ?[]const u8 = null,
    is_shared: bool = false,
};

pub const IsoResult = struct {
    id: []const u8,
    name: []const u8,
    is_shared: bool,
    status: []const u8,
};
