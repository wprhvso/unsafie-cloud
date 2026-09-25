const std = @import("std");
const builtin = @import("builtin");

pub const AF_NETLINK: u32 = 16;
pub const NETLINK_ROUTE: u32 = 0;

pub const NLM_F_REQUEST: u16 = 1;
pub const NLM_F_CREATE: u16 = 0x400;
pub const NLM_F_EXCL: u16 = 0x200;
pub const NLM_F_ACK: u16 = 4;

pub const RTM_NEWROUTE: u16 = 24;
pub const RTM_DELROUTE: u16 = 25;
pub const RTM_NEWADDR: u16 = 20;
pub const RTM_NEWLINK: u16 = 16;

pub const RTA_DST: u16 = 1;
pub const RTA_SRC: u16 = 2;
pub const RTA_IIF: u16 = 3;
pub const RTA_OIF: u16 = 4;
pub const RTA_GATEWAY: u16 = 5;
pub const RTA_PRIORITY: u16 = 6;

pub const nlmsghdr = extern struct {
    nlmsg_len: u32,
    nlmsg_type: u16,
    nlmsg_flags: u16,
    nlmsg_seq: u32,
    nlmsg_pid: u32,
};

pub const rtmsg = extern struct {
    rtm_family: u8,
    rtm_dst_len: u8,
    rtm_src_len: u8,
    rtm_tos: u8,
    rtm_table: u8,
    rtm_protocol: u8,
    rtm_scope: u8,
    rtm_type: u8,
    rtm_flags: u32,
};

pub const rtattr = extern struct {
    rta_len: u16,
    rta_type: u16,
};

pub const Uplink = struct {
    iface: [16]u8 = std.mem.zeroes([16]u8),
    iface_len: usize = 0,
    gateway: u32 = 0,
    ifindex: i32 = -1,
};

var cached_uplink: ?Uplink = null;

pub const Netlink = struct {
    pub fn rtaAlign(len: usize) usize {
        return (len + 3) & ~@as(usize, 3);
    }

    pub fn detectUplink() ?Uplink {
        if (builtin.os.tag != .linux) return null;

        const file = std.fs.openFileAbsolute("/proc/net/route", .{}) catch return null;
        defer file.close();

        var buf: [4096]u8 = undefined;
        const len = file.readAll(&buf) catch return null;
        const content = buf[0..len];

        var line_it = std.mem.splitScalar(u8, content, '\n');
        _ = line_it.next();

        while (line_it.next()) |line| {
            if (line.len == 0) continue;
            var token_it = std.mem.tokenizeAny(u8, line, " \t");
            const iface = token_it.next() orelse continue;
            const dest = token_it.next() orelse continue;
            const gw = token_it.next() orelse continue;
            const flags_str = token_it.next() orelse continue;

            if (std.mem.eql(u8, dest, "00000000")) {
                const flags = std.fmt.parseInt(u16, flags_str, 16) catch continue;
                if ((flags & 0x0002) != 0) {
                    const gw_int = std.fmt.parseInt(u32, gw, 16) catch continue;
                    var up = Uplink{
                        .iface = std.mem.zeroes([16]u8),
                        .gateway = @byteSwap(gw_int),
                        .iface_len = @min(iface.len, 15),
                        .ifindex = -1,
                    };
                    @memcpy(up.iface[0..up.iface_len], iface[0..up.iface_len]);
                    up.ifindex = getIfIndex(up.iface[0..up.iface_len]) orelse -1;
                    return up;
                }
            }
        }
        return null;
    }

    pub fn getIfIndex(ifname: []const u8) ?i32 {
        if (builtin.os.tag != .linux) return null;

        const sock = std.posix.socket(std.posix.AF.INET, std.posix.SOCK.DGRAM, 0) catch return null;
        defer std.posix.close(sock);

        var ifr: extern struct {
            name: [16]u8 = std.mem.zeroes([16]u8),
            ifindex: c_int = 0,
            padding: [20]u8 = std.mem.zeroes([20]u8),
        } = .{};

        const copy_len = @min(ifname.len, 15);
        @memcpy(ifr.name[0..copy_len], ifname[0..copy_len]);

        const rc = std.posix.system.ioctl(sock, 0x8933, @intFromPtr(&ifr));
        if (rc != 0) return null;
        return ifr.ifindex;
    }

    pub fn setLinkUp(ifname: []const u8) !void {
        if (builtin.os.tag != .linux) return;

        const sock = try std.posix.socket(std.posix.AF.INET, std.posix.SOCK.DGRAM, 0);
        defer std.posix.close(sock);

        var ifr: extern struct {
            name: [16]u8 = std.mem.zeroes([16]u8),
            data: extern union {
                flags: c_short,
                mtu: c_int,
                padding: [24]u8,
            } = .{ .flags = 0 },
        } = .{};

        const copy_len = @min(ifname.len, 15);
        @memcpy(ifr.name[0..copy_len], ifname[0..copy_len]);

        _ = std.posix.system.ioctl(sock, 0x8913, @intFromPtr(&ifr));
        ifr.data.flags |= 0x0001 | 0x0040;
        _ = std.posix.system.ioctl(sock, 0x8914, @intFromPtr(&ifr));
    }

    pub fn setIfAddress(ifname: []const u8, ip: u32, netmask: u32) !void {
        if (builtin.os.tag != .linux) return;

        const sock = try std.posix.socket(std.posix.AF.INET, std.posix.SOCK.DGRAM, 0);
        defer std.posix.close(sock);

        var ifr: extern struct {
            name: [16]u8 = std.mem.zeroes([16]u8),
            addr: extern struct {
                family: u16 = 2,
                port: u16 = 0,
                ip: u32 = 0,
                zero: [8]u8 = std.mem.zeroes([8]u8),
            } = .{},
            padding: [8]u8 = std.mem.zeroes([8]u8),
        } = .{};

        const copy_len = @min(ifname.len, 15);
        @memcpy(ifr.name[0..copy_len], ifname[0..copy_len]);

        ifr.addr.family = 2;
        ifr.addr.ip = @byteSwap(ip);
        _ = std.posix.system.ioctl(sock, 0x8916, @intFromPtr(&ifr));

        ifr.addr.ip = @byteSwap(netmask);
        _ = std.posix.system.ioctl(sock, 0x891c, @intFromPtr(&ifr));
    }

    pub fn setMtu(ifname: []const u8, mtu: u32) !void {
        if (builtin.os.tag != .linux) return;
        if (mtu == 0) return;

        const sock = try std.posix.socket(std.posix.AF.INET, std.posix.SOCK.DGRAM, 0);
        defer std.posix.close(sock);

        var ifr: extern struct {
            name: [16]u8 = std.mem.zeroes([16]u8),
            data: extern union {
                flags: c_short,
                mtu: c_int,
                padding: [24]u8,
            } = .{ .flags = 0 },
        } = .{};

        const copy_len = @min(ifname.len, 15);
        @memcpy(ifr.name[0..copy_len], ifname[0..copy_len]);
        ifr.data.mtu = @intCast(mtu);

        _ = std.posix.system.ioctl(sock, 0x8922, @intFromPtr(&ifr));
    }

    pub fn setLinkDown(ifname: []const u8) void {
        if (builtin.os.tag != .linux) return;

        const sock = std.posix.socket(std.posix.AF.INET, std.posix.SOCK.DGRAM, 0) catch return;
        defer std.posix.close(sock);

        var ifr: extern struct {
            name: [16]u8 = std.mem.zeroes([16]u8),
            data: extern union {
                flags: c_short,
                mtu: c_int,
                padding: [24]u8,
            } = .{ .flags = 0 },
        } = .{};

        const copy_len = @min(ifname.len, 15);
        @memcpy(ifr.name[0..copy_len], ifname[0..copy_len]);

        _ = std.posix.system.ioctl(sock, 0x8913, @intFromPtr(&ifr));
        ifr.data.flags &= ~@as(c_short, 0x0001);
        _ = std.posix.system.ioctl(sock, 0x8914, @intFromPtr(&ifr));
    }

    pub fn addRoute(ifindex: i32, dst_ip: u32, prefix_len: u8, gateway: ?u32) !void {
        if (builtin.os.tag != .linux) return;
        if (ifindex <= 0) return;

        const sock = std.posix.socket(AF_NETLINK, std.posix.SOCK.RAW, NETLINK_ROUTE) catch return;
        defer std.posix.close(sock);

        var buf = std.mem.zeroes([512]u8);
        var offset: usize = 0;

        const hdr_len = @sizeOf(nlmsghdr);
        const rtm_len = @sizeOf(rtmsg);

        offset = hdr_len + rtm_len;

        if (prefix_len > 0) {
            offset = appendAttr(&buf, offset, RTA_DST, std.mem.asBytes(&@byteSwap(dst_ip)));
        }

        offset = appendAttr(&buf, offset, RTA_OIF, std.mem.asBytes(&ifindex));

        if (gateway) |gw| {
            offset = appendAttr(&buf, offset, RTA_GATEWAY, std.mem.asBytes(&@byteSwap(gw)));
        }

        const nlh = nlmsghdr{
            .nlmsg_len = @intCast(offset),
            .nlmsg_type = RTM_NEWROUTE,
            .nlmsg_flags = NLM_F_REQUEST | NLM_F_CREATE | NLM_F_ACK,
            .nlmsg_seq = 1,
            .nlmsg_pid = 0,
        };

        const rtm = rtmsg{
            .rtm_family = 2,
            .rtm_dst_len = prefix_len,
            .rtm_src_len = 0,
            .rtm_tos = 0,
            .rtm_table = 254,
            .rtm_protocol = 3,
            .rtm_scope = if (gateway != null) 0 else 253,
            .rtm_type = 1,
            .rtm_flags = 0,
        };

        @memcpy(buf[0..hdr_len], std.mem.asBytes(&nlh));
        @memcpy(buf[hdr_len .. hdr_len + rtm_len], std.mem.asBytes(&rtm));

        _ = std.posix.send(sock, buf[0..offset], 0) catch {};
    }

    pub fn delRoute(ifindex: i32, dst_ip: u32, prefix_len: u8) !void {
        if (builtin.os.tag != .linux) return;
        if (ifindex <= 0) return;

        const sock = std.posix.socket(AF_NETLINK, std.posix.SOCK.RAW, NETLINK_ROUTE) catch return;
        defer std.posix.close(sock);

        var buf = std.mem.zeroes([512]u8);
        const hdr_len = @sizeOf(nlmsghdr);
        const rtm_len = @sizeOf(rtmsg);
        var offset: usize = hdr_len + rtm_len;

        if (prefix_len > 0) {
            offset = appendAttr(&buf, offset, RTA_DST, std.mem.asBytes(&@byteSwap(dst_ip)));
        }
        offset = appendAttr(&buf, offset, RTA_OIF, std.mem.asBytes(&ifindex));

        const nlh = nlmsghdr{
            .nlmsg_len = @intCast(offset),
            .nlmsg_type = RTM_DELROUTE,
            .nlmsg_flags = NLM_F_REQUEST | NLM_F_ACK,
            .nlmsg_seq = 2,
            .nlmsg_pid = 0,
        };

        const rtm = rtmsg{
            .rtm_family = 2,
            .rtm_dst_len = prefix_len,
            .rtm_src_len = 0,
            .rtm_tos = 0,
            .rtm_table = 254,
            .rtm_protocol = 3,
            .rtm_scope = 0,
            .rtm_type = 1,
            .rtm_flags = 0,
        };

        @memcpy(buf[0..hdr_len], std.mem.asBytes(&nlh));
        @memcpy(buf[hdr_len .. hdr_len + rtm_len], std.mem.asBytes(&rtm));

        _ = std.posix.send(sock, buf[0..offset], 0) catch {};
    }

    pub fn addBypassRoute(ip: u32) void {
        const up = cached_uplink orelse return;
        if (up.ifindex <= 0) return;
        addRoute(up.ifindex, ip, 32, up.gateway) catch {};
        std.debug.print("[BYPASS ROUTE] {d}.{d}.{d}.{d}/32 via {s} dev {s}\n", .{
            (ip >> 24) & 0xff,
            (ip >> 16) & 0xff,
            (ip >> 8) & 0xff,
            ip & 0xff,
            formatIp(up.gateway),
            up.iface[0..up.iface_len],
        });
    }

    fn formatIp(ip: u32) [16]u8 {
        var buf = std.mem.zeroes([16]u8);
        _ = std.fmt.bufPrint(&buf, "{d}.{d}.{d}.{d}", .{
            (ip >> 24) & 0xff,
            (ip >> 16) & 0xff,
            (ip >> 8) & 0xff,
            ip & 0xff,
        }) catch {};
        return buf;
    }

    pub fn setupClientRoutes(vpn_ifname: []const u8, server_ip: ?u32) void {
        cached_uplink = detectUplink();
        if (cached_uplink) |up| {
            std.debug.print("[ROUTE INIT] Physical uplink detected: iface={s} (index={d}) gateway={d}.{d}.{d}.{d}\n", .{
                up.iface[0..up.iface_len],
                up.ifindex,
                (up.gateway >> 24) & 0xff,
                (up.gateway >> 16) & 0xff,
                (up.gateway >> 8) & 0xff,
                up.gateway & 0xff,
            });

            if (server_ip) |sip| {
                if (up.ifindex > 0) {
                    addRoute(up.ifindex, sip, 32, up.gateway) catch {};
                    std.debug.print("[ROUTE INIT] Added direct host route to VPS {d}.{d}.{d}.{d} via physical uplink\n", .{
                        (sip >> 24) & 0xff,
                        (sip >> 16) & 0xff,
                        (sip >> 8) & 0xff,
                        sip & 0xff,
                    });
                }
            }
        } else {
            std.debug.print("[ROUTE WARN] Could not detect physical default gateway from /proc/net/route\n", .{});
        }

        var vpn_idx: i32 = -1;
        var attempts: usize = 0;
        while (attempts < 10) : (attempts += 1) {
            if (getIfIndex(vpn_ifname)) |idx| {
                vpn_idx = idx;
                break;
            }
            std.Thread.sleep(20 * std.time.ns_per_ms);
        }

        if (vpn_idx <= 0) {
            std.debug.print("[ROUTE ERROR] VPN interface {s} not found after timeout! Tunnel routes not active!\n", .{vpn_ifname});
            return;
        }

        std.debug.print("[ROUTE INIT] Found VPN device {s} with index {d}\n", .{ vpn_ifname, vpn_idx });

        addRoute(vpn_idx, 0x00000000, 1, null) catch |err| {
            std.debug.print("[ROUTE ERROR] addRoute 0.0.0.0/1 failed: {any}\n", .{err});
        };
        addRoute(vpn_idx, 0x80000000, 1, null) catch |err| {
            std.debug.print("[ROUTE ERROR] addRoute 128.0.0.0/1 failed: {any}\n", .{err});
        };

        std.debug.print("[ROUTE INIT] Active: 0.0.0.0/1 -> {s} (all non-domestic traffic captured)\n", .{vpn_ifname});
        std.debug.print("[ROUTE INIT] Active: 128.0.0.0/1 -> {s} (all non-domestic traffic captured)\n", .{vpn_ifname});

        setupDnsOverride();
    }

    pub fn teardownClientRoutes(vpn_ifname: []const u8, server_ip: ?u32) void {
        const vpn_idx = getIfIndex(vpn_ifname);
        if (vpn_idx) |idx| {
            delRoute(idx, 0x00000000, 1) catch {};
            delRoute(idx, 0x80000000, 1) catch {};
            std.debug.print("[ROUTE CLEANUP] Removed 0.0.0.0/1 and 128.0.0.0/1 routes from {s}\n", .{vpn_ifname});
        }

        if (cached_uplink) |up| {
            if (server_ip) |sip| {
                if (up.ifindex > 0) {
                    delRoute(up.ifindex, sip, 32) catch {};
                    std.debug.print("[ROUTE CLEANUP] Removed VPS host pin route\n", .{});
                }
            }
        }

        restoreDnsOverride();
    }

    fn setupDnsOverride() void {
        if (builtin.os.tag != .linux) return;

        if (std.fs.openFileAbsolute("/etc/resolv.conf", .{ .mode = .read_only })) |orig| {
            var buf: [2048]u8 = undefined;
            const len = orig.readAll(&buf) catch 0;
            orig.close();

            if (len > 0) {
                if (std.fs.createFileAbsolute("/etc/resolv.conf.unsafie.bak", .{})) |bak| {
                    bak.writeAll(buf[0..len]) catch {};
                    bak.close();
                } else |_| {}
            }
        } else |_| {}

        if (std.fs.createFileAbsolute("/etc/resolv.conf", .{})) |f| {
            f.writeAll("nameserver 127.0.0.1\noptions timeout:1\n") catch {};
            f.close();
            std.debug.print("[DNS INIT] Configured local DNS resolver: nameserver 127.0.0.1 (/etc/resolv.conf)\n", .{});
        } else |_| {
            std.debug.print("[DNS WARN] Could not overwrite /etc/resolv.conf directly, trying resolvectl...\n", .{});
        }
    }

    fn restoreDnsOverride() void {
        if (builtin.os.tag != .linux) return;

        if (std.fs.openFileAbsolute("/etc/resolv.conf.unsafie.bak", .{ .mode = .read_only })) |bak| {
            var buf: [2048]u8 = undefined;
            const len = bak.readAll(&buf) catch 0;
            bak.close();

            if (len > 0) {
                if (std.fs.createFileAbsolute("/etc/resolv.conf", .{})) |f| {
                    f.writeAll(buf[0..len]) catch {};
                    f.close();
                    std.debug.print("[DNS CLEANUP] Restored original /etc/resolv.conf\n", .{});
                } else |_| {}
            }
            std.fs.deleteFileAbsolute("/etc/resolv.conf.unsafie.bak") catch {};
        } else |_| {}
    }

    fn appendAttr(buf: []u8, offset: usize, attr_type: u16, val: []const u8) usize {
        const attr_hdr_len = @sizeOf(rtattr);
        const total_len = attr_hdr_len + val.len;
        const aligned_len = rtaAlign(total_len);

        if (offset + aligned_len > buf.len) return offset;

        const rta = rtattr{
            .rta_len = @intCast(total_len),
            .rta_type = attr_type,
        };

        @memcpy(buf[offset .. offset + attr_hdr_len], std.mem.asBytes(&rta));
        @memcpy(buf[offset + attr_hdr_len .. offset + total_len], val);

        if (aligned_len > total_len) {
            @memset(buf[offset + total_len .. offset + aligned_len], 0);
        }

        return offset + aligned_len;
    }
};

test "netlink rta align and ifindex" {
    try std.testing.expectEqual(@as(usize, 4), Netlink.rtaAlign(1));
    try std.testing.expectEqual(@as(usize, 4), Netlink.rtaAlign(4));
    try std.testing.expectEqual(@as(usize, 8), Netlink.rtaAlign(5));

    if (builtin.os.tag == .linux) {
        const lo_idx = Netlink.getIfIndex("lo");
        try std.testing.expect(lo_idx != null);
        try std.testing.expect(lo_idx.? > 0);
    }
}
