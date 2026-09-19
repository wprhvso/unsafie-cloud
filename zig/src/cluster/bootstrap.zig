const std = @import("std");
const runner = @import("../ansible/runner.zig");

pub const Bootstrapper = struct {
    ansible_runner: runner.AnsibleRunner,

    pub fn init(ansible_runner: runner.AnsibleRunner) Bootstrapper {
        return .{ .ansible_runner = ansible_runner };
    }

    pub fn bootstrapNode(self: Bootstrapper, target_ip: []const u8, extra_vars: ?[]const u8) !void {
        try self.ansible_runner.runPlaybook(target_ip, "bootstrap_peer.yml", extra_vars);
    }
};
