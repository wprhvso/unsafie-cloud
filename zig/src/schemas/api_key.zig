const std = @import("std");

pub const ApiKeyEnsureParams = struct {
    name: []const u8,
    owner: []const u8,
    scopes: ?[][]const u8 = null,
};

pub const ApiKeyResult = struct {
    id: []const u8,
    name: []const u8,
    key_prefix: []const u8,
    secret_key: ?[]const u8 = null,
};
