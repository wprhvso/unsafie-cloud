const std = @import("std");
const ws_h2 = @import("../vpn/transport/websocket_h2.zig");
const tun = @import("../vpn/tun.zig");

pub const TcpListener = struct {
    port: u16,
    sock_fd: std.posix.fd_t = -1,
    running: std.atomic.Value(bool),
    thread: ?std.Thread = null,
    key: [32]u8 = [_]u8{0} ** 32,
    active_client_fd: std.atomic.Value(std.posix.fd_t),

    pub fn init(port: u16) TcpListener {
        return .{
            .port = port,
            .sock_fd = -1,
            .running = std.atomic.Value(bool).init(false),
            .thread = null,
            .key = [_]u8{0} ** 32,
            .active_client_fd = std.atomic.Value(std.posix.fd_t).init(-1),
        };
    }

    pub fn start(self: *TcpListener, key: [32]u8, tun_dev: *tun.TunDevice) !void {
        if (self.running.load(.seq_cst)) return;
        self.key = key;

        const sock = try std.posix.socket(std.posix.AF.INET, std.posix.SOCK.STREAM, 0);
        errdefer std.posix.close(sock);

        const enable: u32 = 1;
        try std.posix.setsockopt(sock, std.posix.SOL.SOCKET, std.posix.SO.REUSEADDR, std.mem.asBytes(&enable));

        const addr = std.net.Address.initIp4([4]u8{ 0, 0, 0, 0 }, self.port);
        try std.posix.bind(sock, &addr.any, addr.getOsSockLen());
        try std.posix.listen(sock, 128);

        self.sock_fd = sock;
        self.running.store(true, .seq_cst);
        self.thread = try std.Thread.spawn(.{}, acceptLoop, .{ self, tun_dev });
    }

    pub fn stop(self: *TcpListener) void {
        if (!self.running.load(.seq_cst)) return;
        self.running.store(false, .seq_cst);

        const active = self.active_client_fd.swap(-1, .seq_cst);
        if (active >= 0) {
            std.posix.close(active);
        }

        if (self.sock_fd >= 0) {
            std.posix.close(self.sock_fd);
            self.sock_fd = -1;
        }

        if (self.thread) |t| {
            t.join();
            self.thread = null;
        }
    }

    fn acceptLoop(self: *TcpListener, tun_dev: *tun.TunDevice) void {
        while (self.running.load(.seq_cst)) {
            var client_addr: std.posix.sockaddr.in = undefined;
            var client_len: std.posix.socklen_t = @sizeOf(std.posix.sockaddr.in);

            const client_fd = std.posix.accept(
                self.sock_fd,
                @ptrCast(&client_addr),
                &client_len,
                0,
            ) catch break;

            const old = self.active_client_fd.swap(client_fd, .seq_cst);
            if (old >= 0) std.posix.close(old);

            self.handleClient(client_fd, tun_dev);
        }
    }

    fn handleClient(self: *TcpListener, client_fd: std.posix.fd_t, tun_dev: *tun.TunDevice) void {
        var recv_buf: [4096]u8 = undefined;
        var plain_buf: [2048]u8 = undefined;

        while (self.running.load(.seq_cst)) {
            const n = std.posix.recv(client_fd, &recv_buf, 0) catch break;
            if (n == 0) break;
            if (n < 24) continue;

            const plain_len = ws_h2.WebSocketH2.unpackSecureWs(self.key, recv_buf[0..n], &plain_buf) catch continue;
            _ = tun_dev.writePacket(plain_buf[0..plain_len]) catch {};
        }
    }
};
