const std = @import("std");
const masque = @import("../vpn/transport/masque.zig");
const tun = @import("../vpn/tun.zig");
const logger_mod = @import("../logging/logger.zig");

pub const UdpListener = struct {
    port: u16,
    sock_fd: std.posix.fd_t = -1,
    running: std.atomic.Value(bool),
    thread: ?std.Thread = null,
    last_peer: ?std.net.Address = null,
    peer_lock: std.Thread.Mutex = .{},
    key: [32]u8 = [_]u8{0} ** 32,
    tx_counter: std.atomic.Value(u64),
    logger: ?*logger_mod.StructuredLogger = null,

    pub fn init(port: u16) UdpListener {
        return .{
            .port = port,
            .sock_fd = -1,
            .running = std.atomic.Value(bool).init(false),
            .thread = null,
            .last_peer = null,
            .peer_lock = .{},
            .key = [_]u8{0} ** 32,
            .tx_counter = std.atomic.Value(u64).init(1),
            .logger = null,
        };
    }

    pub fn start(self: *UdpListener, key: [32]u8, tun_dev: *tun.TunDevice) !void {
        if (self.running.load(.seq_cst)) return;
        self.key = key;

        const sock = try std.posix.socket(std.posix.AF.INET, std.posix.SOCK.DGRAM, 0);
        errdefer std.posix.close(sock);

        const addr = std.net.Address.initIp4([4]u8{ 0, 0, 0, 0 }, self.port);
        try std.posix.bind(sock, &addr.any, addr.getOsSockLen());

        self.sock_fd = sock;
        self.running.store(true, .seq_cst);
        self.thread = try std.Thread.spawn(.{}, workerLoop, .{ self, tun_dev });

        if (self.logger) |lg| {
            lg.logSystem("INFO", "edge", "udp_started", "UDP 443 listener active");
        }
    }

    pub fn stop(self: *UdpListener) void {
        if (!self.running.load(.seq_cst)) return;
        self.running.store(false, .seq_cst);

        if (self.sock_fd >= 0) {
            std.posix.close(self.sock_fd);
            self.sock_fd = -1;
        }

        if (self.thread) |t| {
            t.join();
            self.thread = null;
        }
    }

    pub fn sendToClient(self: *UdpListener, payload: []const u8) !void {
        self.peer_lock.lock();
        const peer = self.last_peer;
        self.peer_lock.unlock();

        const p = peer orelse return;
        if (self.sock_fd < 0) return;

        var buf: [2048]u8 = undefined;
        const ctr = self.tx_counter.fetchAdd(1, .monotonic);
        const len = try masque.Masque.packSecure(self.key, ctr, 0, payload, &buf);

        _ = std.posix.sendto(self.sock_fd, buf[0..len], 0, &p.any, p.getOsSockLen()) catch {};

        if (self.logger) |lg| {
            lg.logTraffic("outbound", "server", 443, "client", 0, "MASQUE", "forward_egress", "server_to_client", @intCast(payload.len), "eth0");
        }
    }

    fn workerLoop(self: *UdpListener, tun_dev: *tun.TunDevice) void {
        var recv_buf: [4096]u8 = undefined;
        var plain_buf: [2048]u8 = undefined;

        while (self.running.load(.seq_cst)) {
            var src_addr: std.posix.sockaddr.in = undefined;
            var src_len: std.posix.socklen_t = @sizeOf(std.posix.sockaddr.in);

            const n = std.posix.recvfrom(
                self.sock_fd,
                &recv_buf,
                0,
                @ptrCast(&src_addr),
                &src_len,
            ) catch break;

            if (n < 24) continue;

            const res = masque.Masque.unpackSecure(self.key, recv_buf[0..n], &plain_buf) catch continue;

            self.peer_lock.lock();
            self.last_peer = std.net.Address{ .any = @bitCast(src_addr) };
            self.peer_lock.unlock();

            _ = tun_dev.writePacket(plain_buf[0..res.payload_len]) catch {};

            if (self.logger) |lg| {
                lg.logTraffic("inbound", "client", 0, "server", 443, "MASQUE", "inject_tun", "client_to_server", @intCast(res.payload_len), "unsafie0");
            }
        }
    }
};
