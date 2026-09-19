const std = @import("std");

pub const ZeroCopyProxy = struct {
    pub fn spliceStream(in_fd: std.posix.fd_t, out_fd: std.posix.fd_t) !void {
        _ = in_fd;
        _ = out_fd;
    }
};
