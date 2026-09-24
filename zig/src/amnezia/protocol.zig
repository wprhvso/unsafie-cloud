const std = @import("std");

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
    mesh_sync,
    unknown,
};

pub fn identifyPacket(header_bytes: [4]u8, params: AmneziaParams) PacketType {
    const val = std.mem.readInt(u32, &header_bytes, .little);
    if (val == params.h1) return .handshake_init;
    if (val == params.h2) return .handshake_resp;
    if (val == params.h3) return .cookie;
    if (val == params.h4) return .transport_data;
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

    std.mem.writeInt(u32, out[0..4], params.h1, .little);
    std.mem.writeInt(u32, out[4..8], sender_index, .little);
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

    std.mem.writeInt(u32, out[0..4], params.h2, .little);
    std.mem.writeInt(u32, out[4..8], sender_index, .little);
    std.mem.writeInt(u32, out[8..12], receiver_index, .little);
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

    std.mem.writeInt(u32, out[0..4], params.h4, .little);
    std.mem.writeInt(u32, out[4..8], receiver_index, .little);
    std.mem.writeInt(u64, out[8..16], counter, .little);
    @memcpy(out[16 .. 16 + ciphertext.len], ciphertext);
    @memcpy(out[16 + ciphertext.len .. total_len], &tag);

    return total_len;
}

pub fn buildSyncPacket(
    out: []u8,
    timestamp: i64,
    sender_pubkey: [32]u8,
    mac: [16]u8,
    yaml_payload: []const u8,
) !usize {
    const total_len = 4 + 8 + 32 + 16 + 4 + yaml_payload.len;
    if (out.len < total_len) return error.BufferTooSmall;

    std.mem.writeInt(u32, out[0..4], SYNC_MAGIC, .little);
    std.mem.writeInt(i64, out[4..12], timestamp, .little);
    @memcpy(out[12..44], &sender_pubkey);
    @memcpy(out[44..60], &mac);
    std.mem.writeInt(u32, out[60..64], @intCast(yaml_payload.len), .little);
    @memcpy(out[64..total_len], yaml_payload);

    return total_len;
}
