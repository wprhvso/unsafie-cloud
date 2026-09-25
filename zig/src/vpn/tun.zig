const std = @import("std");
const linux = std.os.linux;

pub const IFF_TUN: c_short = 0x0001;
pub const IFF_NO_PI: c_short = 0x1000;
pub const TUNSETIFF: usize = 0x400454ca;

pub const IfReq = extern struct {
    name: [16]u8 = @as([16]u8, @splat(0)),
    flags: c_short = 0,
    padding: [22]u8 = @as([22]u8, @splat(0)),
};

pub const TunDevice = struct {
    fd: i32 = -1,
    name: [16]u8 = @as([16]u8, @splat(0)),
    allocator: std.mem.Allocator,

    pub fn initWithFd(allocator: std.mem.Allocator, fd: i32) TunDevice {
        return .{
            .fd = fd,
            .name = @as([16]u8, @splat(0)),
            .allocator = allocator,
        };
    }

    pub fn init(allocator: std.mem.Allocator, ifname: []const u8) !TunDevice {
        const flags = linux.O{ .ACCMODE = .RDWR };
        const fd_rc = linux.open("/dev/net/tun", flags, 0);
        if (@as(isize, @bitCast(fd_rc)) < 0) {
            return .{ .fd = -1, .name = @as([16]u8, @splat(0)), .allocator = allocator };
        }
        const fd: i32 = @intCast(fd_rc);

        var req: IfReq = .{};
        req.flags = IFF_TUN | IFF_NO_PI;
        const copy_len = @min(ifname.len, 15);
        @memcpy(req.name[0..copy_len], ifname[0..copy_len]);

        const rc = linux.ioctl(fd, TUNSETIFF, @intFromPtr(&req));
        if (rc != 0) {
            _ = linux.close(fd);
            return .{ .fd = -1, .name = @as([16]u8, @splat(0)), .allocator = allocator };
        }

        return TunDevice{
            .fd = fd,
            .name = req.name,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *TunDevice) void {
        if (self.fd >= 0) {
            _ = linux.close(self.fd);
            self.fd = -1;
        }
    }

    pub fn readPacket(self: *TunDevice, buf: []u8) !usize {
        if (self.fd < 0) return 0;
        var pfd = [1]linux.pollfd{.{
            .fd = self.fd,
            .events = linux.POLL.IN,
            .revents = 0,
        }};
        const rc = linux.poll(&pfd, 1, 50);
        if (rc <= 0 or (pfd[0].revents & linux.POLL.IN) == 0) return 0;

        const n = linux.read(self.fd, buf.ptr, buf.len);
        if (n < 0) return 0;
        return @intCast(n);
    }

    pub fn writePacket(self: *TunDevice, buf: []const u8) !usize {
        if (self.fd < 0) return buf.len;
        const n = linux.write(self.fd, buf.ptr, buf.len);
        if (n < 0) return 0;
        return @intCast(n);
    }
};
