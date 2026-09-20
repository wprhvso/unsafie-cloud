const std = @import("std");

pub const SockFilter = extern struct {
    code: u16,
    jt: u8,
    jf: u8,
    k: u32,
};

pub const SockFprog = extern struct {
    len: u16,
    filter: [*]const SockFilter,
};

pub const BpfSilencer = struct {
    pub fn buildRstFilter() [8]SockFilter {
        return [_]SockFilter{
            .{ .code = 0x28, .jt = 0, .jf = 0, .k = 12 },
            .{ .code = 0x15, .jt = 0, .jf = 5, .k = 0x0800 },
            .{ .code = 0x30, .jt = 0, .jf = 0, .k = 23 },
            .{ .code = 0x15, .jt = 0, .jf = 3, .k = 6 },
            .{ .code = 0x30, .jt = 0, .jf = 0, .k = 47 },
            .{ .code = 0x45, .jt = 1, .jf = 0, .k = 0x04 },
            .{ .code = 0x06, .jt = 0, .jf = 0, .k = 0 },
            .{ .code = 0x06, .jt = 0, .jf = 0, .k = 0xffff },
        };
    }

    pub fn attachFilter(sock_fd: std.posix.fd_t) !void {
        const filter = buildRstFilter();
        const prog = SockFprog{
            .len = filter.len,
            .filter = &filter,
        };

        const SO_ATTACH_FILTER: u32 = 26;
        const SOL_SOCKET: u32 = 1;

        _ = std.posix.system.setsockopt(
            sock_fd,
            SOL_SOCKET,
            SO_ATTACH_FILTER,
            @ptrCast(&prog),
            @sizeOf(SockFprog),
        );
    }

    pub fn silenceViaFirewall(port: u16) void {
        var port_buf: [16]u8 = undefined;
        const port_str = std.fmt.bufPrint(&port_buf, "{d}", .{port}) catch return;

        var child = std.process.Child.init(&[_][]const u8{
            "iptables", "-I", "OUTPUT", "-p", "tcp", "--tcp-flags", "RST", "RST", "--sport", port_str, "-j", "DROP",
        }, std.heap.page_allocator);
        _ = child.spawnAndWait() catch {};
    }
};
