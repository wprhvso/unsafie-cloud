const std = @import("std");
const bundle = @import("bundle.zig");

pub const AnsibleRunner = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) AnsibleRunner {
        return .{ .allocator = allocator };
    }

    pub fn runPlaybook(self: AnsibleRunner, target_ip: []const u8, playbook_name: []const u8, extra_vars: ?[]const u8) !void {
        var rand_bytes: [8]u8 = undefined;
        std.crypto.random.bytes(&rand_bytes);
        var run_id_buf: [16]u8 = undefined;
        _ = try std.fmt.bufPrint(&run_id_buf, "{s}", .{std.fmt.fmtSliceHexLower(&rand_bytes)});

        const temp_path = try std.fmt.allocPrint(self.allocator, "/tmp/unsafie-ansible-{s}", .{run_id_buf});
        defer self.allocator.free(temp_path);

        try std.fs.cwd().makePath(temp_path);
        defer std.fs.cwd().deleteTree(temp_path) catch {};

        const tar_dest = try std.fs.path.join(self.allocator, &[_][]const u8{ temp_path, "bundle.tar" });
        defer self.allocator.free(tar_dest);
        try std.fs.cwd().writeFile(.{ .sub_path = tar_dest, .data = bundle.embedded_playbooks });

        var tar_child = std.process.Child.init(&[_][]const u8{ "tar", "-xf", tar_dest, "-C", temp_path }, self.allocator);
        _ = try tar_child.spawnAndWait();

        const inv_path = try std.fs.path.join(self.allocator, &[_][]const u8{ temp_path, "hosts.ini" });
        defer self.allocator.free(inv_path);
        const inv_content = try std.fmt.allocPrint(self.allocator, "target ansible_host={s} ansible_user=root ansible_ssh_common_args='-o StrictHostKeyChecking=no'\n", .{target_ip});
        defer self.allocator.free(inv_content);
        try std.fs.cwd().writeFile(.{ .sub_path = inv_path, .data = inv_content });

        const pb_path = try std.fs.path.join(self.allocator, &[_][]const u8{ temp_path, playbook_name });
        defer self.allocator.free(pb_path);

        const vars_arg = extra_vars orelse "{}";
        var pb_child = std.process.Child.init(&[_][]const u8{
            "ansible-playbook",
            "-i",
            inv_path,
            pb_path,
            "--extra-vars",
            vars_arg,
        }, self.allocator);

        _ = try pb_child.spawnAndWait();
    }
};
