const std = @import("std");
const builtin = @import("builtin");
const windows = @import("platform/windows.zig");

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

        const file = std.fs.openFileAbsolute("/dev/net/tun", .{ .mode = .read_write }) catch {
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
        if (builtin.os.tag == .windows) return;
        var child1 = std.process.Child.init(&[_][]const u8{ "ip", "link", "set", ifname, "up", "mtu", "1420" }, std.heap.page_allocator);
        _ = child1.spawnAndWait() catch {};
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
