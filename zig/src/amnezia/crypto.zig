const std = @import("std");

pub fn derivePublicKey(private_key: [32]u8) [32]u8 {
    return std.crypto.dh.X25519.recoverPublicKey(private_key) catch [_]u8{0} ** 32;
}

pub fn computeSharedSecret(private_key: [32]u8, public_key: [32]u8) ![32]u8 {
    return std.crypto.dh.X25519.scalarmult(private_key, public_key);
}

pub fn encryptPayload(ciphertext: []u8, tag: *[16]u8, plaintext: []const u8, nonce: [12]u8, key: [32]u8) void {
    std.crypto.aead.chacha_poly.ChaCha20Poly1305.encrypt(ciphertext, tag, plaintext, "", nonce, key);
}

pub fn decryptPayload(plaintext: []u8, ciphertext: []const u8, tag: [16]u8, nonce: [12]u8, key: [32]u8) !void {
    try std.crypto.aead.chacha_poly.ChaCha20Poly1305.decrypt(plaintext, ciphertext, tag, "", nonce, key);
}

pub fn computeMac(out: *[16]u8, data: []const u8, key: []const u8) void {
    var full_hash: [32]u8 = undefined;
    if (key.len > 0) {
        var b2 = std.crypto.hash.blake2.Blake2s256.init(.{ .key = key });
        b2.update(data);
        b2.final(&full_hash);
    } else {
        std.crypto.hash.blake2.Blake2s256.hash(data, &full_hash, .{});
    }
    @memcpy(out, full_hash[0..16]);
}

pub fn parseKey(str: []const u8) [32]u8 {
    var out = [_]u8{0} ** 32;
    if (str.len == 64) {
        if (std.fmt.hexToBytes(&out, str)) |_| {
            return out;
        } else |_| {}
    }
    if (str.len == 44) {
        if (std.base64.standard.Decoder.decode(&out, str)) |_| {
            return out;
        } else |_| {}
    }
    const copy_len = @min(str.len, 32);
    @memcpy(out[0..copy_len], str[0..copy_len]);
    return out;
}
