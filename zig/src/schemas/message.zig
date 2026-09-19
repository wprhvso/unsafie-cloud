const std = @import("std");

pub const RequestFrame = struct {
    id: []const u8,
    action: []const u8,
    token: ?[]const u8 = null,
    params: ?std.json.Value = null,
};

pub const ResponseFrame = struct {
    id: []const u8,
    status: []const u8,
    changed: bool = false,
    result: ?std.json.Value = null,
    error_message: ?[]const u8 = null,
};

pub const EventFrame = struct {
    event: []const u8,
    data: std.json.Value,
};
