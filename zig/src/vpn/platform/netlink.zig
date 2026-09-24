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

pub const Netlink = struct {
    pub fn rtaAlign(len: usize) usize {
        return (len + 3) & ~@as(usize, 3);
    }

    pub fn getIfIndex(ifname: []const u8) ?i32 {
        if (builtin.os.tag != .linux) return null;

        const sock = std.posix.socket(std.posix.AF.INET, std.posix.SOCK.DGRAM, 0) catch return null;
        defer std.posix.close(sock);

        var ifr: extern struct {
            name: [16]u8 = [_]u8{0} ** 16,
            ifindex: c_int = 0,
            padding: [20]u8 = [_]u8{0} ** 20,
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
            name: [16]u8 = [_]u8{0} ** 16,
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
            name: [16]u8 = [_]u8{0} ** 16,
            addr: extern struct {
                family: u16 = 2,
                port: u16 = 0,
                ip: u32 = 0,
                zero: [8]u8 = [_]u8{0} ** 8,
            } = .{},
            padding: [8]u8 = [_]u8{0} ** 8,
        } = .{};

        const copy_len = @min(ifname.len, 15);
        @memcpy(ifr.name[0..copy_len], ifname[0..copy_len]);

        ifr.addr.family = 2;
        ifr.addr.ip = @byteSwap(ip);
        _ = std.posix.system.ioctl(sock, 0x8916, @intFromPtr(&ifr));

        ifr.addr.ip = @byteSwap(netmask);
        _ = std.posix.system.ioctl(sock, 0x8918, @intFromPtr(&ifr));
    }

    pub fn addRoute(ifindex: i32, dst_ip: u32, prefix_len: u8, gateway: ?u32) !void {
        if (builtin.os.tag != .linux) return;

        const sock = std.posix.socket(AF_NETLINK, std.posix.SOCK.RAW, NETLINK_ROUTE) catch return;
        defer std.posix.close(sock);

        var buf = [_]u8{0} ** 512;
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

        const sock = std.posix.socket(AF_NETLINK, std.posix.SOCK.RAW, NETLINK_ROUTE) catch return;
        defer std.posix.close(sock);

        var buf = [_]u8{0} ** 512;
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

    pub fn setupClientRoutes(vpn_ifname: []const u8, server_ip: ?u32) void {
        const vpn_idx = getIfIndex(vpn_ifname) orelse return;

        if (server_ip) |sip| {
            addRoute(vpn_idx, sip, 32, null) catch {};
        }

        addRoute(vpn_idx, 0x00000000, 1, null) catch {};
        addRoute(vpn_idx, 0x80000000, 1, null) catch {};
    }

    pub fn teardownClientRoutes(vpn_ifname: []const u8, server_ip: ?u32) void {
        const vpn_idx = getIfIndex(vpn_ifname) orelse return;

        delRoute(vpn_idx, 0x00000000, 1) catch {};
        delRoute(vpn_idx, 0x80000000, 1) catch {};

        if (server_ip) |sip| {
            delRoute(vpn_idx, sip, 32) catch {};
        }
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
