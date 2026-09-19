const std = @import("std");

pub const FdHandover = struct {
    pub fn preserveSocketFd(fd: std.posix.fd_t) !void {
        const flags = try std.posix.fcntl(fd, std.posix.F.GETFD, 0);
        _ = try std.posix.fcntl(fd, std.posix.F.SETFD, flags & ~@as(u32, std.posix.FD_CLOEXEC));
    }

    pub fn inheritSocketFd(env_var: []const u8) ?std.posix.fd_t {
        const val = std.posix.getenv(env_var) orelse return null;
        const parsed = std.fmt.parseInt(std.posix.fd_t, val, 10) catch return null;
        return parsed;
    }
};
