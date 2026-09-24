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
const netlink = @import("platform/netlink.zig");
const logger_mod = @import("../logging/logger.zig");
const db_mod = @import("../db/sqlite.zig");

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

    tx_packets: std.atomic.Value(u64),
    tx_bytes: std.atomic.Value(u64),
    rx_packets: std.atomic.Value(u64),
    rx_bytes: std.atomic.Value(u64),

    tun_thread: ?std.Thread = null,
    net_thread: ?std.Thread = null,

    logger: ?*logger_mod.StructuredLogger = null,

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
        self.tx_packets = std.atomic.Value(u64).init(0);
        self.tx_bytes = std.atomic.Value(u64).init(0);
        self.rx_packets = std.atomic.Value(u64).init(0);
        self.rx_bytes = std.atomic.Value(u64).init(0);
        self.tun_thread = null;
        self.net_thread = null;
        self.logger = null;

        silence_rst.BpfSilencer.silenceViaFirewall(443);
        return self;
    }

    pub fn setLogger(self: *VpnService, l: *logger_mod.StructuredLogger) void {
        self.logger = l;
        self.dns_server.logger = l;
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
        if (self.logger) |lg| {
            lg.logSystem("INFO", "vpn", "server_started", "VPN server daemon active on port 443");
        }
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

        const resolved = if (std.net.Address.parseIp4(host, port)) |addr|
            addr
        else |_|
            std.net.Address.resolveIp(host, port) catch std.net.Address.initIp4([4]u8{ 127, 0, 0, 1 }, port);

        self.server_addr = resolved;

        const sock = try std.posix.socket(std.posix.AF.INET, std.posix.SOCK.DGRAM, 0);
        self.client_sock_fd = sock;

        self.running.store(true, .seq_cst);
        try self.dns_server.start(53);

        self.tun_thread = try std.Thread.spawn(.{}, clientTunLoop, .{self});
        self.net_thread = try std.Thread.spawn(.{}, clientNetLoop, .{self});

        if (self.logger) |lg| {
            lg.logSystem("INFO", "vpn", "client_connected", "VPN client active and connected");
        }
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
            const n = self.tun_dev.readPacket(&read_buf) catch {
                std.Thread.sleep(20 * std.time.ns_per_ms);
                continue;
            };
            if (n == 0) {
                std.Thread.sleep(20 * std.time.ns_per_ms);
                continue;
            }
            if (n < 20) continue;

            const dst_ip = std.mem.readInt(u32, read_buf[16..20][0..4], .big);
            const dst_port = if (n >= 24) std.mem.readInt(u16, read_buf[22..24][0..2], .big) else 0;

            const action = self.l3_router.decide(dst_ip, dst_port, false);
            var ip_buf = [_]u8{0} ** 16;
            const ip_str = formatIp(&ip_buf, dst_ip);

            switch (action) {
                .direct => {
                    netlink.Netlink.addBypassRoute(dst_ip);
                    if (self.logger) |lg| {
                        lg.logTraffic("outbound", "10.42.0.2", 0, ip_str, dst_port, "IP", "direct_bypass", "domestic_rules", @intCast(n), "unsafie0");
                    }
                    continue;
                },
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

                    _ = self.tx_packets.fetchAdd(1, .monotonic);
                    _ = self.tx_bytes.fetchAdd(n, .monotonic);

                    if (self.logger) |lg| {
                        lg.logTraffic("outbound", "10.42.0.2", 0, ip_str, dst_port, "IP", "tunnel_exit", "foreign_destination", @intCast(n), "unsafie0");
                    }
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
            ) catch {
                std.Thread.sleep(20 * std.time.ns_per_ms);
                continue;
            };

            if (n < 24) continue;

            const res = masque.Masque.unpackSecure(self.key, recv_buf[0..n], &plain_buf) catch continue;
            _ = self.tun_dev.writePacket(plain_buf[0..res.payload_len]) catch {};

            _ = self.rx_packets.fetchAdd(1, .monotonic);
            _ = self.rx_bytes.fetchAdd(res.payload_len, .monotonic);

            if (self.logger) |lg| {
                lg.logTraffic("inbound", "server", 443, "10.42.0.2", 0, "IP", "tunnel_rx", "vps_response", @intCast(res.payload_len), "unsafie0");
            }
        }
    }

    fn formatIp(buf: *[16]u8, ip: u32) []const u8 {
        return std.fmt.bufPrint(buf, "{d}.{d}.{d}.{d}", .{
            (ip >> 24) & 0xff,
            (ip >> 16) & 0xff,
            (ip >> 8) & 0xff,
            ip & 0xff,
        }) catch "";
    }
};

test "vpn service creation" {
    var vpn_srv = try VpnService.init(std.testing.allocator, "unsafietest0", "10.42.0.0/16");
    defer vpn_srv.deinit();

    vpn_srv.setKeyFromToken("secret-admin-token");
    try std.testing.expectEqual(VpnMode.server, vpn_srv.mode);
}
