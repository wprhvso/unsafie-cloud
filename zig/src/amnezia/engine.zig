const std = @import("std");
const config_mod = @import("../config.zig");
const crypto_mod = @import("crypto.zig");
const protocol_mod = @import("protocol.zig");
const peer_mod = @import("peer.zig");
const router_mod = @import("../routing/router.zig");
const learner_mod = @import("../routing/learner.zig");
const dns_mod = @import("../routing/dns.zig");
const tun_mod = @import("../vpn/tun.zig");

pub const AmneziaEngine = struct {
    allocator: std.mem.Allocator,
    config_path: ?[]const u8,
    config: config_mod.FullConfig,
    tun: tun_mod.TunDevice,
    router: router_mod.SmartRouter,
    learner: learner_mod.LearnerSet,
    dns_srv: dns_mod.DnsServer,
    peers: std.ArrayList(*peer_mod.PeerSession),
    udp_socket: std.posix.fd_t = -1,
    running: std.atomic.Value(bool) = std.atomic.Value(bool).init(false),
    threads: [4]?std.Thread = [_]?std.Thread{null} ** 4,
    local_private_key: [32]u8 = [_]u8{0} ** 32,
    local_public_key: [32]u8 = [_]u8{0} ** 32,
    amnezia_params: protocol_mod.AmneziaParams = .{},
    mutex: std.Thread.RwLock = .{},
    active_server_idx: usize = 0,
    server_addr: ?std.net.Address = null,
    next_client_ip: std.atomic.Value(u32) = std.atomic.Value(u32).init(0x0a2a0002),
    assigned_vpn_ip: u32 = 0x0a2a0002,

    pub fn init(allocator: std.mem.Allocator, config_path: ?[]const u8, initial_config: config_mod.FullConfig) !*AmneziaEngine {
        const tun_dev = tun_mod.TunDevice.init(allocator, initial_config.node.vpn_iface) catch tun_mod.TunDevice.initWithFd(allocator, -1);
        return createEngine(allocator, config_path, initial_config, tun_dev);
    }

    pub fn initWithFd(allocator: std.mem.Allocator, config_path: ?[]const u8, initial_config: config_mod.FullConfig, tun_fd: std.posix.fd_t) !*AmneziaEngine {
        const tun_dev = tun_mod.TunDevice.initWithFd(allocator, tun_fd);
        return createEngine(allocator, config_path, initial_config, tun_dev);
    }

    fn createEngine(
        allocator: std.mem.Allocator,
        config_path: ?[]const u8,
        initial_config: config_mod.FullConfig,
        tun_dev: tun_mod.TunDevice,
    ) !*AmneziaEngine {
        const self = try allocator.create(AmneziaEngine);
        errdefer allocator.destroy(self);

        var learner = learner_mod.LearnerSet.init(allocator);
        var router = router_mod.SmartRouter.init(
            allocator,
            &learner,
            initial_config.routing.default_action,
            initial_config.node.vpn_subnet,
        );

        const dns_srv = dns_mod.DnsServer.init(
            allocator,
            initial_config.dns.listen,
            initial_config.dns.upstreams,
            &router,
            &learner,
        );

        self.* = AmneziaEngine{
            .allocator = allocator,
            .config_path = config_path,
            .config = initial_config,
            .tun = tun_dev,
            .router = router,
            .learner = learner,
            .dns_srv = dns_srv,
            .peers = std.ArrayList(*peer_mod.PeerSession){},
            .udp_socket = -1,
            .running = std.atomic.Value(bool).init(false),
            .threads = [_]?std.Thread{null} ** 4,
            .local_private_key = [_]u8{0} ** 32,
            .local_public_key = [_]u8{0} ** 32,
            .amnezia_params = .{
                .jc = initial_config.amnezia.jc,
                .jmin = initial_config.amnezia.jmin,
                .jmax = initial_config.amnezia.jmax,
                .s1 = initial_config.amnezia.s1,
                .s2 = initial_config.amnezia.s2,
                .h1 = initial_config.amnezia.h1,
                .h2 = initial_config.amnezia.h2,
                .h3 = initial_config.amnezia.h3,
                .h4 = initial_config.amnezia.h4,
            },
            .active_server_idx = 0,
            .server_addr = null,
            .next_client_ip = std.atomic.Value(u32).init(0x0a2a0002),
            .assigned_vpn_ip = 0x0a2a0002,
        };

        const keypair = std.crypto.dh.X25519.KeyPair.generate();
        self.local_private_key = keypair.secret_key;
        self.local_public_key = keypair.public_key;

        try self.applyConfig();
        return self;
    }

    pub fn deinit(self: *AmneziaEngine) void {
        self.stop();
        self.clearPeers();
        self.peers.deinit(self.allocator);
        self.dns_srv.deinit();
        self.router.deinit();
        self.learner.deinit();
        self.config.deinit();
        const a = self.allocator;
        a.destroy(self);
    }

    fn clearPeers(self: *AmneziaEngine) void {
        for (self.peers.items) |p| {
            self.allocator.destroy(p);
        }
        self.peers.clearRetainingCapacity();
    }

    pub fn applyConfig(self: *AmneziaEngine) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        self.amnezia_params = .{
            .jc = self.config.amnezia.jc,
            .jmin = self.config.amnezia.jmin,
            .jmax = self.config.amnezia.jmax,
            .s1 = self.config.amnezia.s1,
            .s2 = self.config.amnezia.s2,
            .h1 = self.config.amnezia.h1,
            .h2 = self.config.amnezia.h2,
            .h3 = self.config.amnezia.h3,
            .h4 = self.config.amnezia.h4,
        };

        self.router.direct_cidrs.clearRetainingCapacity();
        for (self.config.routing.direct_cidrs) |c| {
            try self.router.addDirectCidr(c);
        }

        self.router.direct_domains.clearRetainingCapacity();
        for (self.config.routing.direct_domains) |d| {
            try self.router.addDirectDomain(d);
        }

        self.router.blocked_domains.clearRetainingCapacity();
        for (self.config.routing.blocked_domains) |b| {
            try self.router.addBlockedDomain(b);
        }

        self.router.routed_domains.clearRetainingCapacity();
        for (self.config.routing.routed_domains) |rd| {
            try self.router.addRoutedDomain(rd);
        }

        for (self.config.dns.hosts) |h| {
            if (router_mod.parseIpv4(h.ip)) |hip| {
                self.dns_srv.addHost(h.name, hip) catch {};
            }
        }
    }

    pub fn start(self: *AmneziaEngine) !void {
        if (self.running.load(.seq_cst)) return;

        const port = if (self.config.node.mode == .server) self.config.node.listen_port else 0;
        const bind_addr = std.net.Address.initIp4([_]u8{0} ** 4, port);

        const sock = try std.posix.socket(std.posix.AF.INET, std.posix.SOCK.DGRAM, 0);

        const reuse: c_int = 1;
        _ = std.posix.setsockopt(sock, std.posix.SOL.SOCKET, std.posix.SO.REUSEADDR, std.mem.asBytes(&reuse)) catch {};

        try std.posix.bind(sock, &bind_addr.any, bind_addr.getOsSockLen());
        self.udp_socket = sock;
        self.running.store(true, .seq_cst);

        if (self.config.node.mode == .server) {
            self.dns_srv.start() catch {};
        }

        self.threads[0] = try std.Thread.spawn(.{}, udpLoop, .{self});
        self.threads[1] = try std.Thread.spawn(.{}, tunLoop, .{self});
        self.threads[2] = try std.Thread.spawn(.{}, maintenanceLoop, .{self});

        if (self.config.node.mode == .client or self.config.node.mode == .admin) {
            self.threads[3] = try std.Thread.spawn(.{}, clientInitLoop, .{self});
        }
    }

    pub fn stop(self: *AmneziaEngine) void {
        if (!self.running.load(.seq_cst)) return;
        self.running.store(false, .seq_cst);

        self.dns_srv.stop();
        self.tun.deinit();

        for (&self.threads) |*opt_t| {
            if (opt_t.*) |t| {
                t.join();
                opt_t.* = null;
            }
        }

        if (self.udp_socket >= 0) {
            std.posix.close(self.udp_socket);
            self.udp_socket = -1;
        }
    }

    fn clientInitLoop(self: *AmneziaEngine) void {
        self.connectToNextServer();

        if (self.config.node.mode == .client and self.config.node.smart_routing) {
            self.performStunLocalCheck();
        }

        self.sendHandshakeInit();
    }

    fn connectToNextServer(self: *AmneziaEngine) void {
        if (self.config.node.servers.len == 0) return;
        const s_str = self.config.node.servers[self.active_server_idx % self.config.node.servers.len];
        var host = s_str;
        var port: u16 = 51820;
        if (std.mem.indexOfScalar(u8, s_str, ':')) |colon| {
            host = s_str[0..colon];
            port = std.fmt.parseInt(u16, s_str[colon + 1 ..], 10) catch 51820;
        }

        if (router_mod.parseIpv4(host)) |hip| {
            self.server_addr = std.net.Address.initIp4(@as([4]u8, @bitCast(std.mem.nativeToBig(u32, hip))), port);
        }
    }

    fn performStunLocalCheck(self: *AmneziaEngine) void {
        const dest = self.server_addr orelse return;

        var tx_id: [12]u8 = undefined;
        std.crypto.random.bytes(&tx_id);

        var stun_req: [32]u8 = undefined;
        const req_len = protocol_mod.buildStunRequest(&stun_req, tx_id) catch return;

        const stun_sock = std.posix.socket(std.posix.AF.INET, std.posix.SOCK.DGRAM, 0) catch return;
        defer std.posix.close(stun_sock);

        const timeout = std.posix.timeval{ .sec = 1, .usec = 0 };
        _ = std.posix.setsockopt(stun_sock, std.posix.SOL.SOCKET, std.posix.SO.RCVTIMEO, std.mem.asBytes(&timeout)) catch {};

        var attempts: usize = 0;
        while (attempts < 3 and self.running.load(.seq_cst)) : (attempts += 1) {
            _ = std.posix.sendto(
                stun_sock,
                stun_req[0..req_len],
                0,
                &dest.any,
                dest.getOsSockLen(),
            ) catch {};

            var resp_buf: [64]u8 = undefined;
            const n = std.posix.recv(stun_sock, &resp_buf, 0) catch continue;
            if (protocol_mod.parseStunResponse(resp_buf[0..n], tx_id)) |stun_res| {
                const is_ru = self.router.rules_engine.matchIp(stun_res.ip);
                self.router.is_russian_client = is_ru;
                break;
            }
        }
    }

    fn sendHandshakeInit(self: *AmneziaEngine) void {
        const dest = self.server_addr orelse return;

        protocol_mod.sendJunkPackets(
            self.udp_socket,
            dest,
            self.amnezia_params.jc,
            self.amnezia_params.jmin,
            self.amnezia_params.jmax,
        );

        const enc_static = [_]u8{0} ** 48;
        const enc_ts = [_]u8{0} ** 28;
        var mac1 = [_]u8{0} ** 16;
        const mac2 = [_]u8{0} ** 16;

        const effective_token = if (self.config.node.token.len > 0) self.config.node.token else self.config.amnezia.psk;
        crypto_mod.computeMac(&mac1, &self.local_public_key, effective_token);

        var init_buf: [512]u8 = undefined;
        const total_len = protocol_mod.buildHandshakeInit(
            &init_buf,
            self.amnezia_params,
            1,
            self.local_public_key,
            enc_static,
            enc_ts,
            mac1,
            mac2,
        ) catch return;

        _ = std.posix.sendto(
            self.udp_socket,
            init_buf[0..total_len],
            0,
            &dest.any,
            dest.getOsSockLen(),
        ) catch {};
    }

    fn udpLoop(self: *AmneziaEngine) void {
        var buf: [4096]u8 = undefined;

        while (self.running.load(.seq_cst)) {
            if (self.udp_socket < 0) break;

            var pfd = [1]std.posix.pollfd{.{
                .fd = self.udp_socket,
                .events = std.posix.POLL.IN,
                .revents = 0,
            }};
            const rc = std.posix.poll(&pfd, 100) catch break;
            if (rc == 0 or (pfd[0].revents & std.posix.POLL.IN) == 0) continue;

            var src_addr: std.posix.sockaddr.in = undefined;
            var addr_len: std.posix.socklen_t = @sizeOf(std.posix.sockaddr.in);

            const n = std.posix.recvfrom(
                self.udp_socket,
                &buf,
                0,
                @ptrCast(&src_addr),
                &addr_len,
            ) catch {
                if (!self.running.load(.seq_cst)) break;
                continue;
            };

            if (n < 4) continue;

            const ep = std.net.Address{ .in = .{ .sa = src_addr } };
            self.handleInboundUdp(buf[0..n], ep);
        }
    }

    fn handleInboundUdp(self: *AmneziaEngine, packet: []const u8, src_addr: std.net.Address) void {
        const ptype = protocol_mod.identifyPacket(packet, self.amnezia_params);

        switch (ptype) {
            .stun_req => {
                if (packet.len < 16) return;
                var tx_id: [12]u8 = undefined;
                @memcpy(&tx_id, packet[4..16]);

                const client_ip = std.mem.bigToNative(u32, @as(u32, @bitCast(src_addr.in.sa.addr)));
                const client_port = std.mem.bigToNative(u16, src_addr.in.sa.port);

                var stun_resp: [32]u8 = undefined;
                const resp_len = protocol_mod.buildStunResponse(&stun_resp, tx_id, client_ip, client_port) catch return;

                _ = std.posix.sendto(
                    self.udp_socket,
                    stun_resp[0..resp_len],
                    0,
                    &src_addr.any,
                    src_addr.getOsSockLen(),
                ) catch {};
            },
            .stun_resp => {},
            .handshake_init => {
                if (self.config.node.mode != .server) return;
                if (packet.len < 148) return;

                const sender_idx = std.mem.readInt(u32, packet[4..8][0..4], .little);
                var client_pub: [32]u8 = undefined;
                @memcpy(&client_pub, packet[8..40]);

                const mac1 = packet[116..132];
                var expected_mac: [16]u8 = undefined;
                const effective_token = if (self.config.node.client_token.len > 0) self.config.node.client_token else self.config.amnezia.psk;
                crypto_mod.computeMac(&expected_mac, &client_pub, effective_token);

                if (!std.mem.eql(u8, mac1, &expected_mac)) return;

                const client_vpn_ip = self.next_client_ip.fetchAdd(1, .monotonic);

                self.mutex.lock();
                var found: ?*peer_mod.PeerSession = null;
                for (self.peers.items) |p| {
                    if (std.mem.eql(u8, &p.public_key, &client_pub)) {
                        found = p;
                        break;
                    }
                }

                if (found == null) {
                    if (self.allocator.create(peer_mod.PeerSession)) |new_peer| {
                        new_peer.* = peer_mod.PeerSession{
                            .name = "ephemeral-client",
                            .role = "client",
                            .public_key = client_pub,
                            .endpoint = src_addr,
                            .allowed_ip = client_vpn_ip,
                            .allowed_mask = 0xffffffff,
                            .can_sync_config = false,
                            .persistent_keepalive = 25,
                            .session_key = crypto_mod.parseKey(effective_token),
                        };
                        new_peer.has_session.store(true, .monotonic);
                        self.peers.append(self.allocator, new_peer) catch {};
                        found = new_peer;
                    } else |_| {}
                } else if (found) |p| {
                    p.endpoint = src_addr;
                    p.has_session.store(true, .monotonic);
                }
                self.mutex.unlock();

                var resp_buf: [512]u8 = undefined;
                const resp_len = protocol_mod.buildHandshakeResp(
                    &resp_buf,
                    self.amnezia_params,
                    1,
                    sender_idx,
                    self.local_public_key,
                    [_]u8{0} ** 16,
                    [_]u8{0} ** 16,
                    [_]u8{0} ** 16,
                ) catch return;

                protocol_mod.sendJunkPackets(
                    self.udp_socket,
                    src_addr,
                    self.amnezia_params.jc,
                    self.amnezia_params.jmin,
                    self.amnezia_params.jmax,
                );

                _ = std.posix.sendto(
                    self.udp_socket,
                    resp_buf[0..resp_len],
                    0,
                    &src_addr.any,
                    src_addr.getOsSockLen(),
                ) catch {};
            },
            .handshake_resp => {
                if (packet.len < 92) return;
                self.mutex.lock();
                if (self.peers.items.len == 0) {
                    if (self.allocator.create(peer_mod.PeerSession)) |server_peer| {
                        server_peer.* = peer_mod.PeerSession{
                            .name = "server",
                            .role = "server",
                            .public_key = [_]u8{0} ** 32,
                            .endpoint = src_addr,
                            .allowed_ip = 0,
                            .allowed_mask = 0,
                            .can_sync_config = true,
                            .persistent_keepalive = 25,
                            .session_key = crypto_mod.parseKey(if (self.config.node.token.len > 0) self.config.node.token else self.config.amnezia.psk),
                        };
                        server_peer.has_session.store(true, .monotonic);
                        self.peers.append(self.allocator, server_peer) catch {};
                    } else |_| {}
                }
                self.mutex.unlock();
            },
            .transport_data => {
                if (packet.len < 32) return;
                const receiver_idx = std.mem.readInt(u32, packet[4..8][0..4], .little);
                _ = receiver_idx;

                const counter = std.mem.readInt(u64, packet[8..16][0..8], .little);
                const tag_idx = packet.len - 16;
                const ciphertext = packet[16..tag_idx];
                const tag = packet[tag_idx..packet.len][0..16].*;

                var nonce = [_]u8{0} ** 12;
                std.mem.writeInt(u64, nonce[4..12][0..8], counter, .little);

                const effective_token = if (self.config.node.token.len > 0)
                    self.config.node.token
                else if (self.config.node.client_token.len > 0)
                    self.config.node.client_token
                else
                    self.config.amnezia.psk;

                var psk_key = [_]u8{0} ** 32;
                @memcpy(psk_key[0..@min(effective_token.len, 32)], effective_token[0..@min(effective_token.len, 32)]);

                var decrypted_buf: [2048]u8 = undefined;
                if (ciphertext.len > decrypted_buf.len) return;

                crypto_mod.decryptPayload(decrypted_buf[0..ciphertext.len], ciphertext, tag, nonce, psk_key) catch return;

                _ = self.tun.writePacket(decrypted_buf[0..ciphertext.len]) catch {};

                self.mutex.lockShared();
                if (self.peers.items.len > 0) {
                    self.peers.items[0].recordRx(packet.len);
                }
                self.mutex.unlockShared();
            },
            .push_signal => {
                if (packet.len < 16) return;
                const subtype = std.mem.readInt(u32, packet[4..8][0..4], .little);

                if (subtype == 1 and self.config.node.mode == .server) {
                    if (packet.len < 36) return;
                    const auth_mac = packet[16..32];
                    var expected_mac: [16]u8 = undefined;
                    crypto_mod.computeMac(&expected_mac, packet[36..], self.config.node.admin_token);
                    if (!std.mem.eql(u8, auth_mac, &expected_mac)) return;

                    self.broadcastPushReload();
                } else if (subtype == 2 and (self.config.node.mode == .client or self.config.node.mode == .admin)) {
                    self.learner.sweep();
                    self.applyConfig() catch {};
                }
            },
            .mesh_sync, .cookie, .unknown => {},
        }
    }

    pub fn broadcastPushReload(self: *AmneziaEngine) void {
        self.mutex.lockShared();
        defer self.mutex.unlockShared();

        var reload_buf: [32]u8 = undefined;
        const total = protocol_mod.buildPushReload(&reload_buf, std.time.timestamp()) catch return;

        for (self.peers.items) |p| {
            if (p.endpoint) |ep| {
                _ = std.posix.sendto(
                    self.udp_socket,
                    reload_buf[0..total],
                    0,
                    &ep.any,
                    ep.getOsSockLen(),
                ) catch {};
            }
        }
    }

    fn tunLoop(self: *AmneziaEngine) void {
        var buf: [2048]u8 = undefined;

        while (self.running.load(.seq_cst)) {
            const n = self.tun.readPacket(&buf) catch {
                if (!self.running.load(.seq_cst)) break;
                std.Thread.sleep(10 * std.time.ns_per_ms);
                continue;
            };

            if (n == 0) continue;
            if (n < 20) continue;
            const version = buf[0] >> 4;
            if (version != 4) continue;

            const dst_ip = std.mem.readInt(u32, buf[16..20][0..4], .big);
            const action = self.router.decide(dst_ip, null);

            switch (action) {
                .direct, .drop => continue,
                .mesh => {
                    self.sendViaMesh(buf[0..n], dst_ip);
                },
            }
        }
    }

    fn sendViaMesh(self: *AmneziaEngine, ip_packet: []const u8, dst_ip: u32) void {
        self.mutex.lockShared();
        defer self.mutex.unlockShared();

        var target_peer: ?*peer_mod.PeerSession = null;
        for (self.peers.items) |p| {
            if (p.matchesIp(dst_ip)) {
                target_peer = p;
                break;
            }
        }

        if (target_peer == null and self.peers.items.len > 0) {
            target_peer = self.peers.items[0];
        }

        const peer = target_peer orelse return;
        const dest_ep = peer.endpoint orelse return;

        const counter = peer.tx_counter.fetchAdd(1, .monotonic);
        var nonce = [_]u8{0} ** 12;
        std.mem.writeInt(u64, nonce[4..12][0..8], counter, .little);

        var ciphertext_buf: [2048]u8 = undefined;
        if (ip_packet.len > ciphertext_buf.len) return;

        var tag: [16]u8 = undefined;
        const effective_token = if (self.config.node.token.len > 0)
            self.config.node.token
        else if (self.config.node.client_token.len > 0)
            self.config.node.client_token
        else
            self.config.amnezia.psk;

        var psk_key = [_]u8{0} ** 32;
        @memcpy(psk_key[0..@min(effective_token.len, 32)], effective_token[0..@min(effective_token.len, 32)]);

        crypto_mod.encryptPayload(ciphertext_buf[0..ip_packet.len], &tag, ip_packet, nonce, psk_key);

        var transport_buf: [2100]u8 = undefined;
        const total_len = protocol_mod.buildTransportPacket(
            &transport_buf,
            self.amnezia_params,
            peer.receiver_index,
            counter,
            ciphertext_buf[0..ip_packet.len],
            tag,
        ) catch return;

        _ = std.posix.sendto(
            self.udp_socket,
            transport_buf[0..total_len],
            0,
            &dest_ep.any,
            dest_ep.getOsSockLen(),
        ) catch {};

        peer.recordTx(total_len);
    }

    fn maintenanceLoop(self: *AmneziaEngine) void {
        var tick: u64 = 0;
        while (self.running.load(.seq_cst)) {
            std.Thread.sleep(1 * std.time.ns_per_s);
            tick += 1;

            if (tick % 60 == 0) {
                self.learner.sweep();
            }

            if (tick % 25 == 0) {
                self.mutex.lockShared();
                for (self.peers.items) |p| {
                    if (p.endpoint) |ep| {
                        if (p.persistent_keepalive > 0) {
                            var keepalive_buf: [32]u8 = undefined;
                            const total_len = protocol_mod.buildTransportPacket(
                                &keepalive_buf,
                                self.amnezia_params,
                                p.receiver_index,
                                p.tx_counter.fetchAdd(1, .monotonic),
                                "",
                                [_]u8{0} ** 16,
                            ) catch continue;
                            _ = std.posix.sendto(
                                self.udp_socket,
                                keepalive_buf[0..total_len],
                                0,
                                &ep.any,
                                ep.getOsSockLen(),
                            ) catch {};
                        }
                    }
                }
                self.mutex.unlockShared();
            }
        }
    }
};
