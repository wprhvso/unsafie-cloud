const std = @import("std");

pub const GitBundle = struct {
    pub fn createBundle(allocator: std.mem.Allocator, repo_path: []const u8, output_bundle: []const u8) !void {
        var child = std.process.Child.init(&[_][]const u8{ "git", "-C", repo_path, "bundle", "create", output_bundle, "--all" }, allocator);
        _ = try child.spawnAndWait();
    }

    pub fn restoreBundle(allocator: std.mem.Allocator, bundle_path: []const u8, target_repo_path: []const u8) !void {
        var child = std.process.Child.init(&[_][]const u8{ "git", "clone", bundle_path, target_repo_path }, allocator);
        _ = try child.spawnAndWait();
    }
};
