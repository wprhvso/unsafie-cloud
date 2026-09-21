const std = @import("std");

pub const FleetCrypto = struct {
    pub fn encryptToken(allocator: std.mem.Allocator, master_key: [32]u8, raw_token: []const u8) ![]u8 {
        var nonce: [12]u8 = undefined;
        std.crypto.random.bytes(&nonce);

        const out_len = 12 + raw_token.len + 16;
        const out = try allocator.alloc(u8, out_len);
        errdefer allocator.free(out);

        @memcpy(out[0..12], &nonce);

        var tag: [16]u8 = undefined;
        std.crypto.aead.chacha_poly.ChaCha20Poly1305.encrypt(
            out[12 .. 12 + raw_token.len],
            &tag,
            raw_token,
            "",
            nonce,
            master_key,
        );

        @memcpy(out[12 + raw_token.len .. out_len], &tag);
        return out;
    }

    pub fn decryptToken(allocator: std.mem.Allocator, master_key: [32]u8, enc_payload: []const u8) ![]u8 {
        if (enc_payload.len < 28) return error.InvalidPayloadLength;

        const nonce: [12]u8 = enc_payload[0..12].*;
        const ciphertext_len = enc_payload.len - 28;
        const ciphertext = enc_payload[12 .. 12 + ciphertext_len];
        const tag: [16]u8 = enc_payload[12 + ciphertext_len ..][0..16].*;

        const decrypted = try allocator.alloc(u8, ciphertext_len);
        errdefer allocator.free(decrypted);

        try std.crypto.aead.chacha_poly.ChaCha20Poly1305.decrypt(
            decrypted,
            ciphertext,
            tag,
            "",
            nonce,
            master_key,
        );

        return decrypted;
    }
};
