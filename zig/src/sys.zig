const std = @import("std");
const linux = std.os.linux;

pub fn milliTimestamp() i64 {
    var ts: linux.timespec = undefined;
    _ = linux.clock_gettime(linux.CLOCK.REALTIME, &ts);
    return @as(i64, ts.sec) * 1000 + @divTrunc(ts.nsec, 1_000_000);
}

pub fn timestamp() i64 {
    var ts: linux.timespec = undefined;
    _ = linux.clock_gettime(linux.CLOCK.REALTIME, &ts);
    return @as(i64, ts.sec);
}

pub fn getRandomBytes(buf: []u8) void {
    _ = linux.getrandom(buf.ptr, buf.len, 0);
}

pub fn sleepMs(ms: u32) void {
    var req = linux.timespec{
        .sec = @intCast(@divTrunc(ms, 1000)),
        .nsec = @intCast(@as(u64, ms % 1000) * 1_000_000),
    };
    var rem: linux.timespec = undefined;
    _ = linux.nanosleep(&req, &rem);
}

pub fn getCliArg(allocator: std.mem.Allocator) ?[]const u8 {
    const flags = linux.O{ .ACCMODE = .RDONLY };
    const fd_rc = linux.open("/proc/self/cmdline", flags, 0);
    const fd: i32 = @intCast(fd_rc);
    if (fd < 0) return null;
    defer _ = linux.close(fd);

    var buf: [4096]u8 = undefined;
    const n_rc = linux.read(fd, &buf, buf.len);
    if (n_rc <= 0) return null;
    const n: usize = @intCast(n_rc);

    var it = std.mem.splitScalar(u8, buf[0..n], 0);
    _ = it.next();
    if (it.next()) |arg1| {
        if (arg1.len > 0) {
            return allocator.dupe(u8, arg1) catch null;
        }
    }
    return null;
}

pub fn runSh(cmd: [*:0]const u8) bool {
    const pid_rc = linux.fork();
    if (pid_rc < 0) return false;
    if (pid_rc == 0) {
        const null_env: [0:null]?[*:0]const u8 = .{};
        const sh_candidates = [_][*:0]const u8{
            "/bin/sh",
            "/usr/bin/sh",
            "/run/current-system/sw/bin/sh",
        };
        for (sh_candidates) |sh_path| {
            const argv = [_:null]?[*:0]const u8{ sh_path, "-c", cmd };
            _ = linux.execve(sh_path, &argv, &null_env);
        }
        linux.exit(127);
    }
    var status: u32 = 0;
    _ = linux.wait4(@intCast(pid_rc), @ptrCast(&status), 0, null);
    return (status & 0x7f) == 0 and ((status >> 8) & 0xff) == 0;
}

pub fn setupServerNetworking(ifname: []const u8, vpn_ip: []const u8, vpn_subnet: []const u8, mtu: u32) void {
    const f_flags = linux.O{ .ACCMODE = .WRONLY, .TRUNC = true };
    const f_rc = linux.open("/proc/sys/net/ipv4/ip_forward", f_flags, 0);
    const f_fd: i32 = @intCast(f_rc);
    if (f_fd >= 0) {
        defer _ = linux.close(f_fd);
        _ = linux.write(f_fd, "1\n", 2);
    }

    var cmd_buf: [1024]u8 = undefined;
    if (std.fmt.bufPrint(&cmd_buf, "ip addr add {s} dev {s} 2>/dev/null; ip link set {s} mtu {d} up 2>/dev/null", .{ vpn_ip, ifname, ifname, mtu })) |p| {
        cmd_buf[p.len] = 0;
        _ = runSh(@ptrCast(&cmd_buf));
    } else |_| {}

    if (std.fmt.bufPrint(&cmd_buf, "iptables -t nat -C POSTROUTING -s {s} -j MASQUERADE 2>/dev/null || iptables -t nat -A POSTROUTING -s {s} -j MASQUERADE 2>/dev/null; iptables -C FORWARD -i {s} -j ACCEPT 2>/dev/null || iptables -A FORWARD -i {s} -j ACCEPT 2>/dev/null", .{ vpn_subnet, vpn_subnet, ifname, ifname })) |p| {
        cmd_buf[p.len] = 0;
        _ = runSh(@ptrCast(&cmd_buf));
    } else |_| {}
}

pub fn setupClientNetworking(ifname: []const u8, client_vpn_ip: []const u8, server_endpoint: ?[]const u8, mtu: u32) void {
    var cmd_buf: [1024]u8 = undefined;

    if (std.fmt.bufPrint(&cmd_buf, "ip addr add {s} dev {s} 2>/dev/null; ip link set {s} mtu {d} up 2>/dev/null", .{ client_vpn_ip, ifname, ifname, mtu })) |p| {
        cmd_buf[p.len] = 0;
        _ = runSh(@ptrCast(&cmd_buf));
    } else |_| {}

    if (server_endpoint) |s_ep| {
        var s_host = s_ep;
        if (std.mem.indexOfScalar(u8, s_ep, ':')) |colon| {
            s_host = s_ep[0..colon];
        }
        if (std.fmt.bufPrint(&cmd_buf, "gw=$(ip route show default 2>/dev/null | awk '{{print $3}}'); dev=$(ip route show default 2>/dev/null | awk '{{print $5}}'); [ -n \"$gw\" ] && ip route add {s}/32 via $gw dev $dev 2>/dev/null", .{s_host})) |p| {
            cmd_buf[p.len] = 0;
            _ = runSh(@ptrCast(&cmd_buf));
        } else |_| {}
    }

    if (std.fmt.bufPrint(&cmd_buf, "ip route add 0.0.0.0/1 dev {s} 2>/dev/null; ip route add 128.0.0.0/1 dev {s} 2>/dev/null", .{ ifname, ifname })) |p| {
        cmd_buf[p.len] = 0;
        _ = runSh(@ptrCast(&cmd_buf));
    } else |_| {}
}

pub fn teardownClientNetworking(ifname: []const u8, server_endpoint: ?[]const u8) void {
    var cmd_buf: [1024]u8 = undefined;

    if (std.fmt.bufPrint(&cmd_buf, "ip route del 0.0.0.0/1 dev {s} 2>/dev/null; ip route del 128.0.0.0/1 dev {s} 2>/dev/null; ip link set {s} down 2>/dev/null", .{ ifname, ifname, ifname })) |p| {
        cmd_buf[p.len] = 0;
        _ = runSh(@ptrCast(&cmd_buf));
    } else |_| {}

    if (server_endpoint) |s_ep| {
        var s_host = s_ep;
        if (std.mem.indexOfScalar(u8, s_ep, ':')) |colon| {
            s_host = s_ep[0..colon];
        }
        if (std.fmt.bufPrint(&cmd_buf, "ip route del {s}/32 2>/dev/null", .{s_host})) |p| {
            cmd_buf[p.len] = 0;
            _ = runSh(@ptrCast(&cmd_buf));
        } else |_| {}
    }
}
