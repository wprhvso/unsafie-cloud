const std = @import("std");

pub const GitStore = struct {
    allocator: std.mem.Allocator,
    repo_path: []const u8,

    pub fn init(allocator: std.mem.Allocator, repo_path: []const u8) GitStore {
        return .{
            .allocator = allocator,
            .repo_path = repo_path,
        };
    }

    pub fn ensureRepo(self: GitStore) !void {
        std.fs.cwd().makePath(self.repo_path) catch {};
        var child = std.process.Child.init(&[_][]const u8{ "git", "-C", self.repo_path, "init" }, self.allocator);
        _ = child.spawnAndWait() catch {};
    }

    pub fn commitFile(self: GitStore, rel_path: []const u8, content: []const u8, message: []const u8) !void {
        const full_file_path = try std.fs.path.join(self.allocator, &[_][]const u8{ self.repo_path, rel_path });
        defer self.allocator.free(full_file_path);

        const dir_name = std.fs.path.dirname(full_file_path) orelse self.repo_path;
        std.fs.cwd().makePath(dir_name) catch {};

        try std.fs.cwd().writeFile(.{ .sub_path = full_file_path, .data = content });

        var add_child = std.process.Child.init(&[_][]const u8{ "git", "-C", self.repo_path, "add", rel_path }, self.allocator);
        _ = try add_child.spawnAndWait();

        var commit_child = std.process.Child.init(&[_][]const u8{ "git", "-C", self.repo_path, "commit", "-m", message }, self.allocator);
        _ = commit_child.spawnAndWait() catch {};
    }

    pub fn readFile(self: GitStore, rel_path: []const u8) ![]u8 {
        const full_file_path = try std.fs.path.join(self.allocator, &[_][]const u8{ self.repo_path, rel_path });
        defer self.allocator.free(full_file_path);
        return try std.fs.cwd().readFileAlloc(self.allocator, full_file_path, 10 * 1024 * 1024);
    }
};
