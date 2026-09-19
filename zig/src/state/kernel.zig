const std = @import("std");
const git = @import("git.zig");
const models = @import("models.zig");

pub const KernelState = struct {
    git_store: git.GitStore,

    pub fn init(git_store: git.GitStore) KernelState {
        return .{ .git_store = git_store };
    }

    pub fn setTargetVersion(self: KernelState, allocator: std.mem.Allocator, manifest: models.KernelManifest) !void {
        const json_data = try std.json.stringifyAlloc(allocator, manifest, .{});
        defer allocator.free(json_data);
        try self.git_store.commitFile("cluster/kernel.json", json_data, "kernel(upgrade): target version");
    }
};
