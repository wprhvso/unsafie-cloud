const std = @import("std");

pub const FLAG_FIN: u8 = 0x01;
pub const FLAG_SYN: u8 = 0x02;
pub const FLAG_RST: u8 = 0x04;
pub const FLAG_PSH: u8 = 0x08;
pub const FLAG_ACK: u8 = 0x10;
pub const FLAG_URG: u8 = 0x20;

pub const FakeTcpSession = struct {
    src_ip: u32,
    dst_ip: u32,
    src_port: u16,
    dst_port: u16,
    seq: u32,
    ack: u32,
    state: enum { closed, syn_sent, established } = .closed,

    pub fn init(src_ip: u32, dst_ip: u32, src_port: u16, dst_port: u16) FakeTcpSession {
        return .{
            .src_ip = src_ip,
            .dst_ip = dst_ip,
            .src_port = src_port,
            .dst_port = dst_port,
            .seq = std.crypto.random.int(u32),
            .ack = 0,
            .state = .closed,
        };
    }

    pub fn buildSyn(self: *FakeTcpSession, out: []u8) !usize {
        if (out.len < 20) return error.BufferTooSmall;

        out[0] = @intCast((self.src_port >> 8) & 0xff);
        out[1] = @intCast(self.src_port & 0xff);
        out[2] = @intCast((self.dst_port >> 8) & 0xff);
        out[3] = @intCast(self.dst_port & 0xff);
        std.mem.writeInt(u32, out[4..8][0..4], self.seq, .big);
        std.mem.writeInt(u32, out[8..12][0..4], 0, .big);
        out[12] = 5 << 4;
        out[13] = FLAG_SYN;
        std.mem.writeInt(u16, out[14..16][0..2], 65535, .big);
        out[16] = 0;
        out[17] = 0;
        out[18] = 0;
        out[19] = 0;

        const cksum = computeTcpChecksum(self.src_ip, self.dst_ip, out[0..20]);
        out[16] = @intCast((cksum >> 8) & 0xff);
        out[17] = @intCast(cksum & 0xff);

        self.seq +%= 1;
        self.state = .syn_sent;
        return 20;
    }

    pub fn buildSynAck(self: *FakeTcpSession, remote_seq: u32, out: []u8) !usize {
        if (out.len < 20) return error.BufferTooSmall;

        self.ack = remote_seq +% 1;
        out[0] = @intCast((self.src_port >> 8) & 0xff);
        out[1] = @intCast(self.src_port & 0xff);
        out[2] = @intCast((self.dst_port >> 8) & 0xff);
        out[3] = @intCast(self.dst_port & 0xff);
        std.mem.writeInt(u32, out[4..8][0..4], self.seq, .big);
        std.mem.writeInt(u32, out[8..12][0..4], self.ack, .big);
        out[12] = 5 << 4;
        out[13] = FLAG_SYN | FLAG_ACK;
        std.mem.writeInt(u16, out[14..16][0..2], 65535, .big);
        out[16] = 0;
        out[17] = 0;
        out[18] = 0;
        out[19] = 0;

        const cksum = computeTcpChecksum(self.src_ip, self.dst_ip, out[0..20]);
        out[16] = @intCast((cksum >> 8) & 0xff);
        out[17] = @intCast(cksum & 0xff);

        self.seq +%= 1;
        self.state = .established;
        return 20;
    }

    pub fn buildAck(self: *FakeTcpSession, remote_seq: u32, out: []u8) !usize {
        if (out.len < 20) return error.BufferTooSmall;

        self.ack = remote_seq +% 1;
        out[0] = @intCast((self.src_port >> 8) & 0xff);
        out[1] = @intCast(self.src_port & 0xff);
        out[2] = @intCast((self.dst_port >> 8) & 0xff);
        out[3] = @intCast(self.dst_port & 0xff);
        std.mem.writeInt(u32, out[4..8][0..4], self.seq, .big);
        std.mem.writeInt(u32, out[8..12][0..4], self.ack, .big);
        out[12] = 5 << 4;
        out[13] = FLAG_ACK;
        std.mem.writeInt(u16, out[14..16][0..2], 65535, .big);
        out[16] = 0;
        out[17] = 0;
        out[18] = 0;
        out[19] = 0;

        const cksum = computeTcpChecksum(self.src_ip, self.dst_ip, out[0..20]);
        out[16] = @intCast((cksum >> 8) & 0xff);
        out[17] = @intCast(cksum & 0xff);

        self.state = .established;
        return 20;
    }

    pub fn encapsulate(self: *FakeTcpSession, payload: []const u8, out: []u8) !usize {
        const total_len = 20 + payload.len;
        if (out.len < total_len) return error.BufferTooSmall;

        out[0] = @intCast((self.src_port >> 8) & 0xff);
        out[1] = @intCast(self.src_port & 0xff);
        out[2] = @intCast((self.dst_port >> 8) & 0xff);
        out[3] = @intCast(self.dst_port & 0xff);
        std.mem.writeInt(u32, out[4..8][0..4], self.seq, .big);
        std.mem.writeInt(u32, out[8..12][0..4], self.ack, .big);
        out[12] = 5 << 4;
        out[13] = FLAG_ACK | FLAG_PSH;
        std.mem.writeInt(u16, out[14..16][0..2], 65535, .big);
        out[16] = 0;
        out[17] = 0;
        out[18] = 0;
        out[19] = 0;

        @memcpy(out[20..total_len], payload);
        const cksum = computeTcpChecksum(self.src_ip, self.dst_ip, out[0..total_len]);
        out[16] = @intCast((cksum >> 8) & 0xff);
        out[17] = @intCast(cksum & 0xff);

        self.seq +%= @as(u32, @intCast(payload.len));
        return total_len;
    }

    pub fn decapsulate(self: *FakeTcpSession, raw_packet: []const u8) ![]const u8 {
        if (raw_packet.len < 20) return error.PacketTooShort;
        const offset = (raw_packet[12] >> 4) * 4;
        if (raw_packet.len < offset) return error.InvalidDataOffset;

        const payload = raw_packet[offset..];
        const remote_seq = std.mem.readInt(u32, raw_packet[4..8][0..4], .big);
        self.ack = remote_seq +% @as(u32, @intCast(payload.len));

        return payload;
    }
};

pub fn computeTcpChecksum(src_ip: u32, dst_ip: u32, tcp_bytes: []const u8) u16 {
    var sum: u32 = 0;

    sum += (src_ip >> 16) & 0xffff;
    sum += src_ip & 0xffff;
    sum += (dst_ip >> 16) & 0xffff;
    sum += dst_ip & 0xffff;
    sum += 6;
    sum += @intCast(tcp_bytes.len);

    var i: usize = 0;
    while (i + 1 < tcp_bytes.len) : (i += 2) {
        const word: u16 = (@as(u16, tcp_bytes[i]) << 8) | tcp_bytes[i + 1];
        sum += word;
    }
    if (i < tcp_bytes.len) {
        sum += @as(u16, tcp_bytes[i]) << 8;
    }

    while ((sum >> 16) != 0) {
        sum = (sum & 0xffff) + (sum >> 16);
    }

    return ~@as(u16, @intCast(sum & 0xffff));
}
