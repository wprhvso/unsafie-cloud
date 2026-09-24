const std = @import("std");
const tun = @import("tun.zig");
const ipam = @import("ipam.zig");
const learner = @import("learner.zig");
const rules = @import("rules.zig");
const dns = @import("dns.zig");
const router = @import("router.zig");
const telemetry = @import("mesh/telemetry.zig");
const pathfinder = @import("mesh/pathfinder.zig");
const relay = @import("mesh/relay.zig");
const client_hello = @import("crypto/client_hello.zig");
const fake_tcp = @import("transport/fake_tcp.zig");
const silence_rst = @import("bpf/silence_rst.zig");
const p2p = @import("mesh/p2p.zig");
const stun = @import("mesh/stun.zig");
const timing_wheel = @import("pacing/timing_wheel.zig");
const bbr = @import("pacing/bbr.zig");
const masque = @import("transport/masque.zig");

pub const VpnMode = enum {
    server,
    client,
};

pub const VpnService = struct {
    allocator: std.mem.Allocator,
    mode: VpnMode = .server,
    tun_dev: tun.TunDevice,
    ipam_mgr: ipam.Ipam,
    learner_set: learner.LearnerSet,
    rules_engine: rules.RulesEngine,
    dns_server: dns.DnsServer,
    telem: telemetry.MeshTelemetry,
    pf: pathfinder.Pathfinder,
    blind_relay: relay.BlindRelay,
    l3_router: router.Router,
    tls_generator: client_hello.ChromeClientHello,
    p2p_coordinator: p2p.HolePunchCoordinator,
    tw: timing_wheel.TimingWheel,
    bbr_engine: bbr.BbrController,

    running: std.atomic.Value(bool),
    key: [32]u8 = [_]u8{0} ** 32,
    server_addr: ?std.net.Address = null,
    client_sock_fd: std.posix.fd_t = -1,
    tx_counter: std.atomic.Value(u64),

    tun_thread: ?std.Thread = null,
    net_thread: ?std.Thread = null,

    pub fn init(allocator: std.mem.Allocator, ifname: []const u8, subnet: []const u8) !*VpnService {
        const self = try allocator.create(VpnService);
        errdefer allocator.destroy(self);

        self.allocator = allocator;
        self.mode = .server;
        self.tun_dev = try tun.TunDevice.init(allocator, ifname);
        self.ipam_mgr = ipam.Ipam.init(allocator, subnet);
        self.learner_set = learner.LearnerSet.init(allocator);
        self.rules_engine = rules.RulesEngine.init(allocator);
        self.dns_server = dns.DnsServer.init(allocator, &self.learner_set, &self.rules_engine);
        self.telem = telemetry.MeshTelemetry.init(allocator);
        self.pf = pathfinder.Pathfinder.init(allocator, &self.telem);
        self.blind_relay = relay.BlindRelay.init(allocator);
        self.l3_router = router.Router.init(allocator, &self.learner_set, &self.rules_engine, &self.pf);
        self.tls_generator = client_hello.ChromeClientHello.init(allocator);
        self.p2p_coordinator = p2p.HolePunchCoordinator.init(allocator);
        self.tw = timing_wheel.TimingWheel.init(allocator);
        self.bbr_engine = bbr.BbrController.init();

        self.running = std.atomic.Value(bool).init(false);
        self.key = [_]u8{0} ** 32;
        self.server_addr = null;
        self.client_sock_fd = -1;
        self.tx_counter = std.atomic.Value(u64).init(1);
        self.tun_thread = null;
        self.net_thread = null;

        silence_rst.BpfSilencer.silenceViaFirewall(443);
        return self;
    }

    pub fn setKeyFromToken(self: *VpnService, token: []const u8) void {
        var h = std.crypto.hash.Blake3.init(.{});
        h.update(token);
        h.final(&self.key);
    }

    pub fn startServer(self: *VpnService) !void {
        if (self.running.load(.seq_cst)) return;
        self.mode = .server;
        self.running.store(true, .seq_cst);

        try self.dns_server.start(53);
    }

    pub fn startClient(self: *VpnService, server_endpoint: []const u8) !void {
        if (self.running.load(.seq_cst)) return;
        self.mode = .client;

        var host = server_endpoint;
        var port: u16 = 443;
        if (std.mem.indexOfScalar(u8, server_endpoint, ':')) |colon| {
            host = server_endpoint[0..colon];
            port = std.fmt.parseInt(u16, server_endpoint[colon + 1 ..], 10) catch 443;
        }

        const resolved = std.net.Address.resolveIp(host, port) catch blk: {
            const parsed = std.net.Address.parseIp4(host, port) catch std.net.Address.initIp4([4]u8{ 127, 0, 0, 1 }, port);
            break :blk parsed;
        };
        self.server_addr = resolved;

        const sock = try std.posix.socket(std.posix.AF.INET, std.posix.SOCK.DGRAM, 0);
        self.client_sock_fd = sock;

        self.running.store(true, .seq_cst);
        try self.dns_server.start(53);

        self.tun_thread = try std.Thread.spawn(.{}, clientTunLoop, .{self});
        self.net_thread = try std.Thread.spawn(.{}, clientNetLoop, .{self});
    }

    pub fn stop(self: *VpnService) void {
        if (!self.running.load(.seq_cst)) return;
        self.running.store(false, .seq_cst);

        self.dns_server.stop();

        if (self.client_sock_fd >= 0) {
            std.posix.close(self.client_sock_fd);
            self.client_sock_fd = -1;
        }

        if (self.tun_thread) |t| {
            t.join();
            self.tun_thread = null;
        }

        if (self.net_thread) |t| {
            t.join();
            self.net_thread = null;
        }
    }

    pub fn deinit(self: *VpnService) void {
        self.stop();
        self.tun_dev.deinit();
        self.learner_set.deinit();
        self.dns_server.deinit();
        self.telem.deinit();
        self.pf.deinit();
        self.p2p_coordinator.deinit();
        self.tw.deinit();
        self.allocator.destroy(self);
    }

    fn clientTunLoop(self: *VpnService) void {
        var read_buf: [2048]u8 = undefined;
        var out_buf: [2048]u8 = undefined;

        while (self.running.load(.seq_cst)) {
            const n = self.tun_dev.readPacket(&read_buf) catch break;
            if (n < 20) continue;

            const dst_ip = std.mem.readInt(u32, read_buf[16..20][0..4], .big);
            const dst_port = if (n >= 24) std.mem.readInt(u16, read_buf[22..24][0..2], .big) else 0;

            const action = self.l3_router.decide(dst_ip, dst_port, false);
            switch (action) {
                .direct => continue,
                .drop => continue,
                .mesh_internal, .tunnel_exit => {
                    const s_addr = self.server_addr orelse continue;
                    const ctr = self.tx_counter.fetchAdd(1, .monotonic);
                    const enc_len = masque.Masque.packSecure(self.key, ctr, 0, read_buf[0..n], &out_buf) catch continue;

                    _ = std.posix.sendto(
                        self.client_sock_fd,
                        out_buf[0..enc_len],
                        0,
                        &s_addr.any,
                        s_addr.getOsSockLen(),
                    ) catch {};
                },
            }
        }
    }

    fn clientNetLoop(self: *VpnService) void {
        var recv_buf: [4096]u8 = undefined;
        var plain_buf: [2048]u8 = undefined;

        while (self.running.load(.seq_cst)) {
            var from_addr: std.posix.sockaddr.in = undefined;
            var from_len: std.posix.socklen_t = @sizeOf(std.posix.sockaddr.in);

            const n = std.posix.recvfrom(
                self.client_sock_fd,
                &recv_buf,
                0,
                @ptrCast(&from_addr),
                &from_len,
            ) catch break;

            if (n < 24) continue;

            const res = masque.Masque.unpackSecure(self.key, recv_buf[0..n], &plain_buf) catch continue;
            _ = self.tun_dev.writePacket(plain_buf[0..res.payload_len]) catch {};
        }
    }
};

test "vpn service creation" {
    var vpn_srv = try VpnService.init(std.testing.allocator, "unsafietest0", "10.42.0.0/16");
    defer vpn_srv.deinit();

    vpn_srv.setKeyFromToken("secret-admin-token");
    try std.testing.expectEqual(VpnMode.server, vpn_srv.mode);
}
