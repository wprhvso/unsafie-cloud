const std = @import("std");
const linux = std.os.linux;
const learner_mod = @import("learner.zig");
const router_mod = @import("router.zig");
const protocol_mod = @import("../amnezia/protocol.zig");

pub const DnsServer = struct {
    allocator: std.mem.Allocator,
    listen_addr_str: []const u8,
    upstreams: [][]const u8,
    static_hosts: std.StringHashMap(u32),
    router: *const router_mod.SmartRouter,
    learner: *learner_mod.LearnerSet,
    running: std.atomic.Value(bool),
    sock_fd: i32 = -1,
    thread: ?std.Thread = null,

    pub fn init(
        allocator: std.mem.Allocator,
        listen_addr: []const u8,
        upstreams: [][]const u8,
        router: *const router_mod.SmartRouter,
        learner: *learner_mod.LearnerSet,
    ) DnsServer {
        return .{
            .allocator = allocator,
            .listen_addr_str = listen_addr,
            .upstreams = upstreams,
            .static_hosts = std.StringHashMap(u32).init(allocator),
            .router = router,
            .learner = learner,
            .running = std.atomic.Value(bool).init(false),
            .sock_fd = -1,
            .thread = null,
        };
    }

    pub fn deinit(self: *DnsServer) void {
        self.stop();
        self.static_hosts.deinit();
    }

    pub fn addHost(self: *DnsServer, host: []const u8, ip: u32) !void {
        try self.static_hosts.put(host, ip);
    }

    pub fn start(self: *DnsServer) !void {
        var port: u16 = 53;
        var host_part = self.listen_addr_str;
        if (std.mem.indexOfScalar(u8, self.listen_addr_str, ':')) |colon| {
            host_part = self.listen_addr_str[0..colon];
            port = std.fmt.parseInt(u16, self.listen_addr_str[colon + 1 ..], 10) catch 53;
        }

        const ip = router_mod.parseIpv4(host_part) orelse 0;
        const sock_rc = linux.socket(linux.AF.INET, linux.SOCK.DGRAM, 0);
        const sock: i32 = @intCast(sock_rc);
        if (sock < 0) return error.SocketFailed;

        var sa: linux.sockaddr.in = undefined;
        sa.family = linux.AF.INET;
        sa.port = std.mem.nativeToBig(u16, port);
        sa.addr = @bitCast(std.mem.nativeToBig(u32, ip));

        if (linux.bind(sock, @ptrCast(&sa), @sizeOf(linux.sockaddr.in)) != 0) {
            sa.addr = 0;
            sa.port = 0;
            if (linux.bind(sock, @ptrCast(&sa), @sizeOf(linux.sockaddr.in)) != 0) {
                _ = linux.close(sock);
                return error.BindFailed;
            }
        }

        self.sock_fd = sock;
        self.running.store(true, .seq_cst);
        self.thread = try std.Thread.spawn(.{}, workerLoop, .{self});
    }

    pub fn stop(self: *DnsServer) void {
        if (!self.running.load(.seq_cst)) return;
        self.running.store(false, .seq_cst);
        if (self.thread) |t| {
            t.join();
            self.thread = null;
        }
        if (self.sock_fd >= 0) {
            _ = linux.close(self.sock_fd);
            self.sock_fd = -1;
        }
    }

    fn workerLoop(self: *DnsServer) void {
        var buf: [2048]u8 = undefined;
        var domain_buf: [256]u8 = undefined;
        var ans_buf: [2048]u8 = undefined;

        while (self.running.load(.seq_cst)) {
            if (self.sock_fd < 0) break;

            var pfd = [1]linux.pollfd{.{
                .fd = self.sock_fd,
                .events = linux.POLL.IN,
                .revents = 0,
            }};
            const rc = linux.poll(&pfd, 1, 50);
            if (rc <= 0 or (pfd[0].revents & linux.POLL.IN) == 0) continue;

            var src_addr: linux.sockaddr.in = undefined;
            var addr_len: linux.socklen_t = @sizeOf(linux.sockaddr.in);

            const n_rc = linux.recvfrom(
                self.sock_fd,
                buf[0..].ptr,
                buf.len,
                0,
                @ptrCast(&src_addr),
                &addr_len,
            );
            if (n_rc < 12) continue;
            const n: usize = @intCast(n_rc);

            const parsed = parseDomainName(buf[0..n], 12, &domain_buf);
            if (parsed) |info| {
                if (self.static_hosts.get(info.domain)) |static_ip| {
                    if (buildAAnswer(buf[0..n], static_ip, &ans_buf)) |ans_len| {
                        _ = linux.sendto(
                            self.sock_fd,
                            ans_buf[0..ans_len].ptr,
                            ans_len,
                            0,
                            @ptrCast(&src_addr),
                            addr_len,
                        );
                        continue;
                    }
                }

                if (std.mem.endsWith(u8, info.domain, ".internal")) {
                    if (buildAAnswer(buf[0..n], 0x0a2a0001, &ans_buf)) |ans_len| {
                        _ = linux.sendto(
                            self.sock_fd,
                            ans_buf[0..ans_len].ptr,
                            ans_len,
                            0,
                            @ptrCast(&src_addr),
                            addr_len,
                        );
                        continue;
                    }
                }

                for (self.router.blocked_domains.items) |pat| {
                    if (router_mod.SmartRouter.matchesDomain(pat, info.domain)) {
                        if (buildAAnswer(buf[0..n], 0, &ans_buf)) |ans_len| {
                            _ = linux.sendto(
                                self.sock_fd,
                                ans_buf[0..ans_len].ptr,
                                ans_len,
                                0,
                                @ptrCast(&src_addr),
                                addr_len,
                            );
                        }
                        break;
                    }
                }

                self.forwardUpstream(buf[0..n], info.domain, &src_addr, addr_len);
            }
        }
    }

    fn forwardUpstream(
        self: *DnsServer,
        query: []const u8,
        domain: []const u8,
        client_addr: *const linux.sockaddr.in,
        client_len: linux.socklen_t,
    ) void {
        const sock_rc = linux.socket(linux.AF.INET, linux.SOCK.DGRAM, 0);
        const upstream_sock: i32 = @intCast(sock_rc);
        if (upstream_sock < 0) return;
        defer _ = linux.close(upstream_sock);

        var target_ip: u32 = 0x01010101;
        var target_port: u16 = 53;

        if (self.upstreams.len > 0) {
            var up_str = self.upstreams[0];
            if (std.mem.indexOfScalar(u8, up_str, ':')) |colon| {
                target_port = std.fmt.parseInt(u16, up_str[colon + 1 ..], 10) catch 53;
                up_str = up_str[0..colon];
            }
            target_ip = router_mod.parseIpv4(up_str) orelse 0x01010101;
        }

        var up_sa: linux.sockaddr.in = undefined;
        up_sa.family = linux.AF.INET;
        up_sa.port = std.mem.nativeToBig(u16, target_port);
        up_sa.addr = @bitCast(std.mem.nativeToBig(u32, target_ip));

        _ = linux.sendto(
            upstream_sock,
            query.ptr,
            query.len,
            0,
            @ptrCast(&up_sa),
            @sizeOf(linux.sockaddr.in),
        );

        var pfd = [1]linux.pollfd{.{
            .fd = upstream_sock,
            .events = linux.POLL.IN,
            .revents = 0,
        }};
        if (linux.poll(&pfd, 1, 1500) <= 0) return;

        var resp_buf: [2048]u8 = undefined;
        const resp_rc = linux.read(upstream_sock, resp_buf[0..].ptr, resp_buf.len);
        if (resp_rc < 12) return;
        const resp_len: usize = @intCast(resp_rc);

        self.extractLearnedIps(resp_buf[0..resp_len], domain);

        _ = linux.sendto(
            self.sock_fd,
            resp_buf[0..resp_len].ptr,
            resp_len,
            0,
            @ptrCast(client_addr),
            client_len,
        );
    }

    fn extractLearnedIps(self: *DnsServer, resp: []const u8, domain: []const u8) void {
        var should_learn = self.router.is_russian_client and self.router.rules_engine.matchDomain(domain);
        if (!should_learn) {
            for (self.router.direct_domains.items) |pat| {
                if (router_mod.SmartRouter.matchesDomain(pat, domain)) {
                    should_learn = true;
                    break;
                }
            }
        }
        if (!should_learn) return;

        if (resp.len < 12) return;
        const ancount = std.mem.readInt(u16, resp[6..8][0..2], .big);
        if (ancount == 0) return;

        var offset: usize = 12;
        while (offset < resp.len and resp[offset] != 0) {
            offset += 1 + resp[offset];
        }
        offset += 5;

        var a_idx: u16 = 0;
        while (a_idx < ancount and offset + 12 <= resp.len) : (a_idx += 1) {
            if ((resp[offset] & 0xc0) == 0xc0) {
                offset += 2;
            } else {
                while (offset < resp.len and resp[offset] != 0) {
                    offset += 1 + resp[offset];
                }
                offset += 1;
            }

            if (offset + 10 > resp.len) break;
            const rtype = std.mem.readInt(u16, resp[offset .. offset + 2][0..2], .big);
            const rdlen = std.mem.readInt(u16, resp[offset + 8 .. offset + 10][0..2], .big);
            offset += 10;

            if (rtype == 1 and rdlen == 4 and offset + 4 <= resp.len) {
                const ip = std.mem.readInt(u32, resp[offset .. offset + 4][0..4], .big);
                self.learner.learn(ip) catch {};
            }
            offset += rdlen;
        }
    }
};

pub fn parseDomainName(buf: []const u8, start_offset: usize, out_domain: []u8) ?struct { domain: []const u8, next_offset: usize } {
    var offset = start_offset;
    var out_pos: usize = 0;
    while (offset < buf.len) {
        const len = buf[offset];
        if (len == 0) {
            offset += 1;
            break;
        }
        if ((len & 0xc0) == 0xc0) {
            offset += 2;
            break;
        }
        offset += 1;
        if (offset + len > buf.len) return null;
        if (out_pos > 0 and out_pos < out_domain.len) {
            out_domain[out_pos] = '.';
            out_pos += 1;
        }
        const copy_len = @min(len, out_domain.len - out_pos);
        @memcpy(out_domain[out_pos .. out_pos + copy_len], buf[offset .. offset + copy_len]);
        out_pos += copy_len;
        offset += len;
    }
    return .{
        .domain = out_domain[0..out_pos],
        .next_offset = offset,
    };
}

pub fn buildAAnswer(query: []const u8, ip: u32, out: []u8) ?usize {
    if (query.len < 12 or out.len < query.len + 16) return null;
    @memcpy(out[0..query.len], query);

    out[2] = 0x81;
    out[3] = 0x80;
    out[6] = 0x00;
    out[7] = 0x01;

    const pos = query.len;
    out[pos] = 0xc0;
    out[pos + 1] = 0x0c;
    out[pos + 2] = 0x00;
    out[pos + 3] = 0x01;
    out[pos + 4] = 0x00;
    out[pos + 5] = 0x01;
    out[pos + 6] = 0x00;
    out[pos + 7] = 0x00;
    out[pos + 8] = 0x00;
    out[pos + 9] = 0x3c;
    out[pos + 10] = 0x00;
    out[pos + 11] = 0x04;
    std.mem.writeInt(u32, out[pos + 12 .. pos + 16][0..4], ip, .big);
    return pos + 16;
}
