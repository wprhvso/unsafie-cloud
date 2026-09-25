const std = @import("std");

pub const STUN_MAGIC: u32 = 0x5354554e;
pub const PUSH_MAGIC: u32 = 0x50555348;
pub const SYNC_MAGIC: u32 = 0x53594e43;

pub const AmneziaParams = struct {
    jc: u32 = 4,
    jmin: u32 = 40,
    jmax: u32 = 70,
    s1: u32 = 64,
    s2: u32 = 48,
    h1: u32 = 1287634912,
    h2: u32 = 837194625,
    h3: u32 = 1092837465,
    h4: u32 = 1982736450,
};

pub const PacketType = enum {
    handshake_init,
    handshake_resp,
    cookie,
    transport_data,
    stun_req,
    stun_resp,
    push_signal,
    mesh_sync,
    unknown,
};

pub fn identifyPacket(packet: []const u8, params: AmneziaParams) PacketType {
    if (packet.len < 4) return .unknown;
    const val = std.mem.readInt(u32, packet[0..4][0..4], .little);

    if (val == params.h1) return .handshake_init;
    if (val == params.h2) return .handshake_resp;
    if (val == params.h3) return .cookie;
    if (val == params.h4) return .transport_data;
    if (val == STUN_MAGIC) {
        if (packet.len >= 22) return .stun_resp;
        if (packet.len >= 16) return .stun_req;
    }
    if (val == PUSH_MAGIC) return .push_signal;
    if (val == SYNC_MAGIC) return .mesh_sync;
    return .unknown;
}

pub fn sendJunkPackets(
    sock: std.posix.fd_t,
    dest: std.net.Address,
    count: u32,
    min_size: u32,
    max_size: u32,
) void {
    if (count == 0) return;
    const clamped_min = @max(16, min_size);
    const clamped_max = @min(1420, @max(clamped_min, max_size));
    var junk_buf: [1420]u8 = undefined;

    var i: u32 = 0;
    while (i < count) : (i += 1) {
        const span = clamped_max - clamped_min + 1;
        const rand_size = clamped_min + (std.crypto.random.int(u32) % span);
        std.crypto.random.bytes(junk_buf[0..rand_size]);
        _ = std.posix.sendto(sock, junk_buf[0..rand_size], 0, &dest.any, dest.getOsSockLen()) catch {};
    }
}

pub fn buildStunRequest(out: []u8, tx_id: [12]u8) !usize {
    if (out.len < 16) return error.BufferTooSmall;
    std.mem.writeInt(u32, out[0..4][0..4], STUN_MAGIC, .little);
    @memcpy(out[4..16], &tx_id);
    return 16;
}

pub fn buildStunResponse(out: []u8, tx_id: [12]u8, ip: u32, port: u16) !usize {
    if (out.len < 22) return error.BufferTooSmall;
    std.mem.writeInt(u32, out[0..4][0..4], STUN_MAGIC, .little);
    @memcpy(out[4..16], &tx_id);
    std.mem.writeInt(u32, out[16..20][0..4], ip, .big);
    std.mem.writeInt(u16, out[20..22][0..2], port, .big);
    return 22;
}

pub fn parseStunResponse(packet: []const u8, expected_tx: [12]u8) ?struct { ip: u32, port: u16 } {
    if (packet.len < 22) return null;
    const val = std.mem.readInt(u32, packet[0..4][0..4], .little);
    if (val != STUN_MAGIC) return null;
    if (!std.mem.eql(u8, packet[4..16], &expected_tx)) return null;
    const ip = std.mem.readInt(u32, packet[16..20][0..4], .big);
    const port = std.mem.readInt(u16, packet[20..22][0..2], .big);
    return .{ .ip = ip, .port = port };
}

pub fn buildHandshakeInit(
    out: []u8,
    params: AmneziaParams,
    sender_index: u32,
    ephemeral_pub: [32]u8,
    enc_static: [48]u8,
    enc_timestamp: [28]u8,
    mac1: [16]u8,
    mac2: [16]u8,
) !usize {
    const total_len = 148 + params.s1;
    if (out.len < total_len) return error.BufferTooSmall;

    std.mem.writeInt(u32, out[0..4][0..4], params.h1, .little);
    std.mem.writeInt(u32, out[4..8][0..4], sender_index, .little);
    @memcpy(out[8..40], &ephemeral_pub);
    @memcpy(out[40..88], &enc_static);
    @memcpy(out[88..116], &enc_timestamp);
    @memcpy(out[116..132], &mac1);
    @memcpy(out[132..148], &mac2);

    if (params.s1 > 0) {
        std.crypto.random.bytes(out[148..total_len]);
    }

    return total_len;
}

pub fn buildHandshakeResp(
    out: []u8,
    params: AmneziaParams,
    sender_index: u32,
    receiver_index: u32,
    ephemeral_pub: [32]u8,
    enc_empty: [16]u8,
    mac1: [16]u8,
    mac2: [16]u8,
) !usize {
    const total_len = 92 + params.s2;
    if (out.len < total_len) return error.BufferTooSmall;

    std.mem.writeInt(u32, out[0..4][0..4], params.h2, .little);
    std.mem.writeInt(u32, out[4..8][0..4], sender_index, .little);
    std.mem.writeInt(u32, out[8..12][0..4], receiver_index, .little);
    @memcpy(out[12..44], &ephemeral_pub);
    @memcpy(out[44..60], &enc_empty);
    @memcpy(out[60..76], &mac1);
    @memcpy(out[76..92], &mac2);

    if (params.s2 > 0) {
        std.crypto.random.bytes(out[92..total_len]);
    }

    return total_len;
}

pub fn buildTransportPacket(
    out: []u8,
    params: AmneziaParams,
    receiver_index: u32,
    counter: u64,
    ciphertext: []const u8,
    tag: [16]u8,
) !usize {
    const total_len = 4 + 4 + 8 + ciphertext.len + 16;
    if (out.len < total_len) return error.BufferTooSmall;

    std.mem.writeInt(u32, out[0..4][0..4], params.h4, .little);
    std.mem.writeInt(u32, out[4..8][0..4], receiver_index, .little);
    std.mem.writeInt(u64, out[8..16][0..8], counter, .little);
    @memcpy(out[16 .. 16 + ciphertext.len], ciphertext);
    @memcpy(out[16 + ciphertext.len .. total_len], &tag);

    return total_len;
}

pub fn buildPushReload(out: []u8, timestamp: i64) !usize {
    if (out.len < 16) return error.BufferTooSmall;
    std.mem.writeInt(u32, out[0..4][0..4], PUSH_MAGIC, .little);
    std.mem.writeInt(u32, out[4..8][0..4], 2, .little);
    std.mem.writeInt(i64, out[8..16][0..8], timestamp, .little);
    return 16;
}

pub fn buildPushUpdate(out: []u8, timestamp: i64, auth_hmac: [16]u8, payload: []const u8) !usize {
    const total = 4 + 4 + 8 + 16 + 4 + payload.len;
    if (out.len < total) return error.BufferTooSmall;

    std.mem.writeInt(u32, out[0..4][0..4], PUSH_MAGIC, .little);
    std.mem.writeInt(u32, out[4..8][0..4], 1, .little);
    std.mem.writeInt(i64, out[8..16][0..8], timestamp, .little);
    @memcpy(out[16..32], &auth_hmac);
    std.mem.writeInt(u32, out[32..36][0..4], @intCast(payload.len), .little);
    @memcpy(out[36..total], payload);
    return total;
}
