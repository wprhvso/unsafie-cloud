const std = @import("std");
const learner = @import("learner.zig");
const rules = @import("rules.zig");
const ipam = @import("ipam.zig");

pub const DnsServer = struct {
    allocator: std.mem.Allocator,
    records: std.StringHashMap(u32),
    learner_set: *learner.LearnerSet,
    rules_engine: *const rules.RulesEngine,
    running: std.atomic.Value(bool),
    sock_fd: std.posix.fd_t = -1,
    thread: ?std.Thread = null,
    upstream_ip: u32 = 0x4d580808,
    remote_ip: u32 = 0x01010101,

    pub fn init(allocator: std.mem.Allocator, learner_set: *learner.LearnerSet, rules_engine: *const rules.RulesEngine) DnsServer {
        var records = std.StringHashMap(u32).init(allocator);
        records.put("node1.internal", ipam.Ipam.parseIpv4("10.42.0.1")) catch {};
        records.put("node2.internal", ipam.Ipam.parseIpv4("10.42.0.2")) catch {};
        records.put("node3.internal", ipam.Ipam.parseIpv4("10.42.0.3")) catch {};
        records.put("metrics.internal", ipam.Ipam.parseIpv4("10.42.0.2")) catch {};
        records.put("logs.internal", ipam.Ipam.parseIpv4("10.42.0.2")) catch {};

        return .{
            .allocator = allocator,
            .records = records,
            .learner_set = learner_set,
            .rules_engine = rules_engine,
            .running = std.atomic.Value(bool).init(false),
            .sock_fd = -1,
            .thread = null,
            .upstream_ip = 0x4d580808,
            .remote_ip = 0x01010101,
        };
    }

    pub fn deinit(self: *DnsServer) void {
        self.stop();
        var it = self.records.keyIterator();
        while (it.next()) |k| {
            if (std.mem.startsWith(u8, k.*, "custom.")) {
                self.allocator.free(k.*);
            }
        }
        self.records.deinit();
    }

    pub fn registerRecord(self: *DnsServer, domain: []const u8, ip: u32) !void {
        const key = try self.allocator.dupe(u8, domain);
        try self.records.put(key, ip);
    }

    pub fn resolve(self: *DnsServer, domain: []const u8) ?u32 {
        if (std.mem.endsWith(u8, domain, ".internal")) {
            return self.records.get(domain);
        }

        if (self.rules_engine.isDomesticDomain(domain)) {
            const fallback_ip = ipam.Ipam.parseIpv4("77.88.55.242");
            self.learner_set.learn(fallback_ip) catch {};
            return fallback_ip;
        }

        return null;
    }

    pub fn start(self: *DnsServer, port: u16) !void {
        if (self.running.load(.seq_cst)) return;

        const sock = std.posix.socket(std.posix.AF.INET, std.posix.SOCK.DGRAM, 0) catch |err| {
            return err;
        };

        const addr = std.net.Address.initIp4([4]u8{ 127, 0, 0, 1 }, port);
        std.posix.bind(sock, &addr.any, addr.getOsSockLen()) catch {
            std.posix.close(sock);
            const fallback_addr = std.net.Address.initIp4([4]u8{ 127, 0, 0, 1 }, 5353);
            const sock2 = std.posix.socket(std.posix.AF.INET, std.posix.SOCK.DGRAM, 0) catch return;
            std.posix.bind(sock2, &fallback_addr.any, fallback_addr.getOsSockLen()) catch {
                std.posix.close(sock2);
                self.sock_fd = -1;
                self.running.store(true, .seq_cst);
                return;
            };
            self.sock_fd = sock2;
            self.running.store(true, .seq_cst);
            self.thread = std.Thread.spawn(.{}, workerLoop, .{self}) catch null;
            return;
        };

        self.sock_fd = sock;
        self.running.store(true, .seq_cst);
        self.thread = std.Thread.spawn(.{}, workerLoop, .{self}) catch null;
    }

    pub fn stop(self: *DnsServer) void {
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

    fn workerLoop(self: *DnsServer) void {
        var buf: [2048]u8 = undefined;

        while (self.running.load(.seq_cst)) {
            var client_addr: std.posix.sockaddr.in = undefined;
            var client_addr_len: std.posix.socklen_t = @sizeOf(std.posix.sockaddr.in);

            const n = std.posix.recvfrom(
                self.sock_fd,
                &buf,
                0,
                @ptrCast(&client_addr),
                &client_addr_len,
            ) catch break;

            if (n < 12) continue;

            var qname_buf: [256]u8 = undefined;
            const qname_opt = parseQName(buf[12..n], &qname_buf);

            if (qname_opt) |qname| {
                if (std.mem.endsWith(u8, qname, ".internal")) {
                    if (self.records.get(qname)) |ip| {
                        var resp_buf: [512]u8 = undefined;
                        const resp_len = buildSyntheticResponse(buf[0..n], ip, &resp_buf);
                        _ = std.posix.sendto(
                            self.sock_fd,
                            resp_buf[0..resp_len],
                            0,
                            @ptrCast(&client_addr),
                            client_addr_len,
                        ) catch {};
                        continue;
                    }
                }

                const is_domestic = self.rules_engine.isDomesticDomain(qname);
                const target_dns_ip = if (is_domestic) self.upstream_ip else self.remote_ip;

                var fwd_resp: [2048]u8 = undefined;
                const fwd_len = forwardDnsQuery(buf[0..n], target_dns_ip, &fwd_resp) catch 0;

                if (fwd_len > 12) {
                    if (is_domestic) {
                        extractAndLearnIps(fwd_resp[0..fwd_len], self.learner_set);
                    }
                    _ = std.posix.sendto(
                        self.sock_fd,
                        fwd_resp[0..fwd_len],
                        0,
                        @ptrCast(&client_addr),
                        client_addr_len,
                    ) catch {};
                }
            }
        }
    }

    pub fn parseQName(packet_payload: []const u8, out_buf: []u8) ?[]const u8 {
        var offset: usize = 0;
        var out_offset: usize = 0;

        while (offset < packet_payload.len) {
            const label_len = packet_payload[offset];
            offset += 1;
            if (label_len == 0) break;
            if (label_len > 63) return null;
            if (offset + label_len > packet_payload.len) return null;

            if (out_offset > 0) {
                if (out_offset >= out_buf.len) return null;
                out_buf[out_offset] = '.';
                out_offset += 1;
            }

            if (out_offset + label_len > out_buf.len) return null;
            for (packet_payload[offset .. offset + label_len]) |c| {
                out_buf[out_offset] = std.ascii.toLower(c);
                out_offset += 1;
            }
            offset += label_len;
        }

        if (out_offset == 0) return null;
        return out_buf[0..out_offset];
    }

    fn buildSyntheticResponse(query: []const u8, ip: u32, out: []u8) usize {
        if (query.len < 12 or out.len < query.len + 16) return 0;
        @memcpy(out[0..query.len], query);

        out[2] = 0x81;
        out[3] = 0x80;
        out[6] = 0x00;
        out[7] = 0x01;
        out[8] = 0x00;
        out[9] = 0x00;
        out[10] = 0x00;
        out[11] = 0x00;

        var offset = query.len;
        out[offset] = 0xc0;
        out[offset + 1] = 0x0c;
        offset += 2;

        out[offset] = 0x00;
        out[offset + 1] = 0x01;
        out[offset + 2] = 0x00;
        out[offset + 3] = 0x01;
        offset += 4;

        std.mem.writeInt(u32, out[offset .. offset + 4][0..4], 60, .big);
        offset += 4;

        out[offset] = 0x00;
        out[offset + 1] = 0x04;
        offset += 2;

        std.mem.writeInt(u32, out[offset .. offset + 4][0..4], ip, .big);
        offset += 4;

        return offset;
    }

    fn forwardDnsQuery(query: []const u8, dns_server_ip: u32, out: []u8) !usize {
        const sock = try std.posix.socket(std.posix.AF.INET, std.posix.SOCK.DGRAM, 0);
        defer std.posix.close(sock);

        const tv = std.posix.timeval{ .sec = 1, .usec = 500000 };
        try std.posix.setsockopt(sock, std.posix.SOL.SOCKET, std.posix.SO.RCVTIMEO, std.mem.asBytes(&tv));

        const octets = [4]u8{
            @intCast((dns_server_ip >> 24) & 0xff),
            @intCast((dns_server_ip >> 16) & 0xff),
            @intCast((dns_server_ip >> 8) & 0xff),
            @intCast(dns_server_ip & 0xff),
        };
        const target = std.net.Address.initIp4(octets, 53);

        _ = try std.posix.sendto(sock, query, 0, &target.any, target.getOsSockLen());
        return try std.posix.recv(sock, out, 0);
    }

    fn extractAndLearnIps(resp: []const u8, ls: *learner.LearnerSet) void {
        if (resp.len < 12) return;
        const ancount = std.mem.readInt(u16, resp[6..8][0..2], .big);
        if (ancount == 0) return;

        var offset: usize = 12;
        const qdcount = std.mem.readInt(u16, resp[4..6][0..2], .big);
        var q: usize = 0;
        while (q < qdcount and offset < resp.len) : (q += 1) {
            while (offset < resp.len) {
                const len = resp[offset];
                offset += 1;
                if (len == 0) break;
                if ((len & 0xc0) == 0xc0) {
                    offset += 1;
                    break;
                }
                offset += len;
            }
            offset += 4;
        }

        var a: usize = 0;
        while (a < ancount and offset + 12 <= resp.len) : (a += 1) {
            if ((resp[offset] & 0xc0) == 0xc0) {
                offset += 2;
            } else {
                while (offset < resp.len) {
                    const len = resp[offset];
                    offset += 1;
                    if (len == 0) break;
                    offset += len;
                }
            }

            if (offset + 10 > resp.len) break;
            const rtype = std.mem.readInt(u16, resp[offset .. offset + 2][0..2], .big);
            offset += 8;
            const rdlen = std.mem.readInt(u16, resp[offset .. offset + 2][0..2], .big);
            offset += 2;

            if (rtype == 1 and rdlen == 4 and offset + 4 <= resp.len) {
                const ip = std.mem.readInt(u32, resp[offset .. offset + 4][0..4], .big);
                ls.learn(ip) catch {};
            }
            offset += rdlen;
        }
    }
};

test "dns qname parsing and synthetic response" {
    var query = [_]u8{
        0x12, 0x34, 0x01, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x04, 'n',  'o',  'd',  'e',  0x08, 'i',  'n',  't',  'e',  'r',  'n',
        'a',  'l',  0x00, 0x00, 0x01, 0x00, 0x01,
    };

    var qname_buf: [256]u8 = undefined;
    const name = DnsServer.parseQName(query[12..], &qname_buf);
    try std.testing.expect(name != null);
    try std.testing.expectEqualStrings("node.internal", name.?);

    var resp_buf: [512]u8 = undefined;
    const resp_len = DnsServer.buildSyntheticResponse(&query, 0x0a2a0001, &resp_buf);
    try std.testing.expect(resp_len > query.len);
    try std.testing.expectEqual(@as(u8, 0x81), resp_buf[2]);
    try std.testing.expectEqual(@as(u8, 0x80), resp_buf[3]);
}
