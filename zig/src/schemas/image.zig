const std = @import("std");

pub const ImageResult = struct {
    id: []const u8,
    name: []const u8,
    size_mb: i32,
    status: []const u8,
};
