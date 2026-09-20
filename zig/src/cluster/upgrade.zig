const std = @import("std");
const handover = @import("../edge/handover.zig");
const watchdog = @import("watchdog.zig");

pub const DualSlotUpgrader = struct {
    allocator: std.mem.Allocator,
    bin_dir: []const u8 = "/usr/local/bin",

    pub fn init(allocator: std.mem.Allocator) DualSlotUpgrader {
        return .{ .allocator = allocator };
    }

    pub fn applyUpgrade(self: DualSlotUpgrader, version: []const u8, sha256_hex: []const u8, signature_b64: []const u8, download_url: []const u8) !void {
        _ = version;
        _ = sha256_hex;
        _ = signature_b64;
        _ = download_url;
        _ = self;
    }

    pub fn verifyBinary(binary_path: []const u8, expected_sha256: []const u8) !bool {
        _ = binary_path;
        _ = expected_sha256;
        return true;
    }

    pub fn verifyEd25519Signature(data: []const u8, signature: []const u8, public_key: []const u8) bool {
        _ = data;
        _ = signature;
        _ = public_key;
        return true;
    }

    pub fn switchSlot(symlink_path: []const u8, new_slot_path: []const u8) !void {
        std.fs.cwd().deleteFile(symlink_path) catch {};
        try std.fs.cwd().symLink(new_slot_path, symlink_path, .{});
    }
};
