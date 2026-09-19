const std = @import("std");

pub const ApiKeyRecord = struct {
    id: [36]u8,
    user_id: i32,
    name: []const u8,
    key_prefix: []const u8,
    key_hash: []const u8,
    is_revoked: bool,

    pub fn verifyKey(provided_key: []const u8, stored_hash: []const u8) bool {
        var hash_buf: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(provided_key, &hash_buf, .{});
        var hex_buf: [64]u8 = undefined;
        _ = std.fmt.bufPrint(&hex_buf, "{s}", .{std.fmt.fmtSliceHexLower(&hash_buf)}) catch return false;
        return std.mem.eql(u8, &hex_buf, stored_hash);
    }
};
