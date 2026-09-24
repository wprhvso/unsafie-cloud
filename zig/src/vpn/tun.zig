const std = @import("std");
const builtin = @import("builtin");
const windows = @import("platform/windows.zig");
const netlink = @import("platform/netlink.zig");

pub const IFF_TUN: c_short = 0x0001;
pub const IFF_NO_PI: c_short = 0x1000;
pub const IFF_VNET_HDR: c_short = 0x4000;
pub const TUNSETIFF: usize = 0x400454ca;

pub const IfReq = extern struct {
    name: [16]u8 = [_]u8{0} ** 16,
    flags: c_short = 0,
    padding: [22]u8 = [_]u8{0} ** 22,
};

pub const TunDevice = struct {
    fd: if (builtin.os.tag == .windows) ?*anyopaque else std.posix.fd_t = if (builtin.os.tag == .windows) null else -1,
    name: [16]u8 = [_]u8{0} ** 16,
    allocator: std.mem.Allocator,
    wintun_dev: ?windows.WintunDevice = null,

    pub fn initWithFd(allocator: std.mem.Allocator, fd: std.posix.fd_t) TunDevice {
        return .{
            .fd = fd,
            .name = [_]u8{0} ** 16,
            .allocator = allocator,
            .wintun_dev = null,
        };
    }

    pub fn init(allocator: std.mem.Allocator, ifname: []const u8) !TunDevice {
        if (builtin.os.tag == .windows) {
            const wdev = try windows.WintunDevice.init(allocator, ifname);
            return .{
                .fd = null,
                .name = [_]u8{0} ** 16,
                .allocator = allocator,
                .wintun_dev = wdev,
            };
        }

        const tun_paths = [_][]const u8{
            "/dev/net/tun",
            "/dev/tun",
        };

        var maybe_file: ?std.fs.File = null;
        for (tun_paths) |path| {
            if (std.fs.openFileAbsolute(path, .{ .mode = .read_write })) |f| {
                maybe_file = f;
                break;
            } else |_| {}
        }

        const file = maybe_file orelse {
            return .{
                .fd = -1,
                .name = [_]u8{0} ** 16,
                .allocator = allocator,
            };
        };

        var req: IfReq = .{};
        req.flags = IFF_TUN | IFF_NO_PI;
        const copy_len = @min(ifname.len, 15);
        @memcpy(req.name[0..copy_len], ifname[0..copy_len]);

        const rc = std.posix.system.ioctl(file.handle, TUNSETIFF, @intFromPtr(&req));
        if (rc != 0) {
            file.close();
            return .{
                .fd = -1,
                .name = [_]u8{0} ** 16,
                .allocator = allocator,
            };
        }

        var dev = TunDevice{
            .fd = file.handle,
            .name = req.name,
            .allocator = allocator,
            .wintun_dev = null,
        };

        dev.setupLink(ifname) catch {};
        return dev;
    }

    fn setupLink(self: *TunDevice, ifname: []const u8) !void {
        _ = self;
        if (builtin.os.tag != .linux) return;

        const sock = std.posix.socket(std.posix.AF.INET, std.posix.SOCK.DGRAM, 0) catch return;
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

        ifr.data.mtu = 1420;
        _ = std.posix.system.ioctl(sock, 0x8922, @intFromPtr(&ifr));

        netlink.Netlink.setIfAddress(ifname, 0x0a2a0002, 0xffff0000) catch {};
        netlink.Netlink.setLinkUp(ifname) catch {};

        _ = std.posix.system.ioctl(sock, 0x8913, @intFromPtr(&ifr));
        ifr.data.flags |= 0x0001 | 0x0040;
        _ = std.posix.system.ioctl(sock, 0x8914, @intFromPtr(&ifr));
    }

    pub fn deinit(self: *TunDevice) void {
        if (self.wintun_dev) |*wdev| {
            wdev.deinit();
            self.wintun_dev = null;
        }
        if (builtin.os.tag != .windows) {
            if (self.fd >= 0) {
                std.posix.close(self.fd);
                self.fd = -1;
            }
        }
    }

    pub fn readPacket(self: *TunDevice, buf: []u8) !usize {
        if (self.wintun_dev) |*wdev| {
            return wdev.readPacket(buf);
        }
        if (builtin.os.tag == .windows) return 0;
        if (self.fd < 0) return 0;
        return std.posix.read(self.fd, buf);
    }

    pub fn writePacket(self: *TunDevice, buf: []const u8) !usize {
        if (self.wintun_dev) |*wdev| {
            return wdev.writePacket(buf);
        }
        if (builtin.os.tag == .windows) return buf.len;
        if (self.fd < 0) return buf.len;
        return std.posix.write(self.fd, buf);
    }
};
