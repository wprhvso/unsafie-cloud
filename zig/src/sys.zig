pub fn isSuccess(rc: usize) bool {
    const s: isize = @bitCast(rc);
    return s >= 0;
}

pub fn isError(rc: usize) bool {
    const s: isize = @bitCast(rc);
    return s < 0;
}

const std = @import("std");
const linux = std.os.linux;
const netlink = @import("vpn/platform/netlink.zig");
const Netlink = netlink.Netlink;
const router_mod = @import("routing/router.zig");
const log = @import("log.zig");

pub const SpinLock = log.SpinLock;

pub fn milliTimestamp() i64 {
    return log.milliTimestamp();
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
    if (isError(fd_rc)) return null;
    const fd: i32 = @intCast(fd_rc);
    defer _ = linux.close(fd);

    var buf: [4096]u8 = undefined;
    const n_rc = linux.read(fd, &buf, buf.len);
    if (isError(n_rc) or n_rc == 0) return null;
    const n: usize = @intCast(n_rc);

    var it = std.mem.splitScalar(u8, buf[0..n], 0);
    _ = it.next();
    if (it.next()) |arg1| {
        if (arg1.len > 0) {
            log.debugFmt("sys", "cli_arg_parsed", "Parsed argument from cmdline: {s}", .{arg1});
            return allocator.dupe(u8, arg1) catch null;
        }
    }
    return null;
}

fn execDirect(bin: [*:0]const u8, argv: [*:null]const ?[*:0]const u8) void {
    const pid_rc = linux.fork();
    if (pid_rc < 0) return;
    if (pid_rc == 0) {
        const null_env: [0:null]?[*:0]const u8 = .{};
        _ = linux.execve(bin, argv, &null_env);
        linux.exit(127);
    }
    var status: u32 = 0;
    _ = linux.wait4(@intCast(pid_rc), @ptrCast(&status), 0, null);
}

fn tryApplyMasquerade(vpn_subnet: []const u8, ifname: []const u8) void {
    const candidates = [_][*:0]const u8{
        "/sbin/iptables",
        "/usr/sbin/iptables",
        "/usr/bin/iptables",
    };
    var iptables_path: ?[*:0]const u8 = null;
    for (candidates) |cand| {
        if (linux.access(cand, 1) == 0) {
            iptables_path = cand;
            break;
        }
    }
    const bin = iptables_path orelse {
        log.warn("sys", "iptables_not_found", "No iptables binary found in standard paths, skipping NAT rules");
        return;
    };

    var subnet_buf: [64:0]u8 = undefined;
    if (vpn_subnet.len >= 63) return;
    @memcpy(subnet_buf[0..vpn_subnet.len], vpn_subnet);
    subnet_buf[vpn_subnet.len] = 0;

    var ifname_buf: [32:0]u8 = undefined;
    if (ifname.len >= 31) return;
    @memcpy(ifname_buf[0..ifname.len], ifname);
    ifname_buf[ifname.len] = 0;

    const nat_args = [_:null]?[*:0]const u8{
        bin,
        "-t",
        "nat",
        "-A",
        "POSTROUTING",
        "-s",
        &subnet_buf,
        "-j",
        "MASQUERADE",
    };
    execDirect(bin, &nat_args);

    const fwd_args = [_:null]?[*:0]const u8{
        bin,
        "-A",
        "FORWARD",
        "-i",
        &ifname_buf,
        "-j",
        "ACCEPT",
    };
    execDirect(bin, &fwd_args);
    log.infoFmt("sys", "masquerade_applied", "Applied iptables POSTROUTING MASQUERADE and FORWARD rules for {s} on {s}", .{ vpn_subnet, ifname });
}

pub fn setupServerNetworking(ifname: []const u8, vpn_ip: []const u8, vpn_subnet: []const u8, mtu: u32) void {
    log.infoFmt("sys", "setup_server_networking", "Configuring server networking: iface={s} ip={s} subnet={s} mtu={d}", .{ ifname, vpn_ip, vpn_subnet, mtu });
    const f_flags = linux.O{ .ACCMODE = .WRONLY, .TRUNC = true };
    const f_rc = linux.open("/proc/sys/net/ipv4/ip_forward", f_flags, 0);
    if (isSuccess(f_rc)) {
        const f_fd: i32 = @intCast(f_rc);
        defer _ = linux.close(f_fd);
        _ = linux.write(f_fd, "1\n", 2);
        log.info("sys", "ip_forward_enabled", "Enabled net.ipv4.ip_forward in kernel");
    } else {
        log.warn("sys", "ip_forward_failed", "Failed to open /proc/sys/net/ipv4/ip_forward for writing");
    }

    const ip_cidr = router_mod.parseCidr(vpn_ip);
    const sub_cidr = router_mod.parseCidr(vpn_subnet);
    const mask = if (ip_cidr != null and ip_cidr.?.mask != 0xffffffff)
        ip_cidr.?.mask
    else if (sub_cidr != null)
        sub_cidr.?.mask
    else
        0xffff0000;

    if (ip_cidr) |c| {
        Netlink.setIfAddress(ifname, c.net, mask) catch |err| {
            log.errFmt("sys", "set_address_failed", "Failed to assign IP {s} to {s}: {any}", .{ vpn_ip, ifname, err });
        };
    }
    Netlink.setMtu(ifname, mtu) catch |err| {
        log.errFmt("sys", "set_mtu_failed", "Failed to set MTU {d} on {s}: {any}", .{ mtu, ifname, err });
    };
    Netlink.setLinkUp(ifname) catch |err| {
        log.errFmt("sys", "set_link_up_failed", "Failed to bring {s} up: {any}", .{ ifname, err });
    };

    tryApplyMasquerade(vpn_subnet, ifname);
}

pub fn setupClientNetworking(ifname: []const u8, client_vpn_ip: []const u8, server_endpoint: ?[]const u8, mtu: u32) void {
    log.infoFmt("sys", "setup_client_networking", "Configuring client networking: iface={s} ip={s} mtu={d}", .{ ifname, client_vpn_ip, mtu });
    if (router_mod.parseCidr(client_vpn_ip)) |c| {
        Netlink.setIfAddress(ifname, c.net, c.mask) catch |err| {
            log.errFmt("sys", "set_address_failed", "Failed to assign IP {s} to {s}: {any}", .{ client_vpn_ip, ifname, err });
        };
    }
    Netlink.setMtu(ifname, mtu) catch |err| {
        log.errFmt("sys", "set_mtu_failed", "Failed to set MTU {d} on {s}: {any}", .{ mtu, ifname, err });
    };
    Netlink.setLinkUp(ifname) catch |err| {
        log.errFmt("sys", "set_link_up_failed", "Failed to bring {s} up: {any}", .{ ifname, err });
    };

    var server_ip: ?u32 = null;
    if (server_endpoint) |s_ep| {
        var s_host = s_ep;
        if (std.mem.indexOfScalar(u8, s_ep, ':')) |colon| {
            s_host = s_ep[0..colon];
        }
        server_ip = router_mod.parseIpv4(s_host);
        log.debugFmt("sys", "server_endpoint_resolved", "Resolved server endpoint {s} to host {s}", .{ s_ep, s_host });
    }

    Netlink.setupClientRoutes(ifname, server_ip);
}

pub fn teardownClientNetworking(ifname: []const u8, server_endpoint: ?[]const u8) void {
    log.infoFmt("sys", "teardown_client_networking", "Tearing down client networking for {s}", .{ifname});
    var server_ip: ?u32 = null;
    if (server_endpoint) |s_ep| {
        var s_host = s_ep;
        if (std.mem.indexOfScalar(u8, s_ep, ':')) |colon| {
            s_host = s_ep[0..colon];
        }
        server_ip = router_mod.parseIpv4(s_host);
    }

    Netlink.teardownClientRoutes(ifname, server_ip);
    Netlink.setLinkDown(ifname);
}
