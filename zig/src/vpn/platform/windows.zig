const std = @import("std");
const builtin = @import("builtin");

const conv = if (builtin.os.tag == .windows) std.builtin.CallingConvention.winapi else std.builtin.CallingConvention.c;

pub const WINTUN_ADAPTER_HANDLE = ?*anyopaque;
pub const WINTUN_SESSION_HANDLE = ?*anyopaque;

pub const WintunCreateAdapterFn = *const fn (
    [*:0]const u16,
    [*:0]const u16,
    ?*const anyopaque,
) callconv(conv) WINTUN_ADAPTER_HANDLE;

pub const WintunOpenAdapterFn = *const fn (
    [*:0]const u16,
) callconv(conv) WINTUN_ADAPTER_HANDLE;

pub const WintunCloseAdapterFn = *const fn (
    WINTUN_ADAPTER_HANDLE,
) callconv(conv) void;

pub const WintunStartSessionFn = *const fn (
    WINTUN_ADAPTER_HANDLE,
    u32,
) callconv(conv) WINTUN_SESSION_HANDLE;

pub const WintunEndSessionFn = *const fn (
    WINTUN_SESSION_HANDLE,
) callconv(conv) void;

pub const WintunReceivePacketFn = *const fn (
    WINTUN_SESSION_HANDLE,
    *u32,
) callconv(conv) ?[*]u8;

pub const WintunReleaseReceivePacketFn = *const fn (
    WINTUN_SESSION_HANDLE,
    [*]const u8,
) callconv(conv) void;

pub const WintunAllocateSendPacketFn = *const fn (
    WINTUN_SESSION_HANDLE,
    u32,
) callconv(conv) ?[*]u8;

pub const WintunSendPacketFn = *const fn (
    WINTUN_SESSION_HANDLE,
    [*]const u8,
) callconv(conv) void;

pub const WintunDevice = struct {
    adapter: WINTUN_ADAPTER_HANDLE = null,
    session: WINTUN_SESSION_HANDLE = null,
    lib: ?std.DynLib = null,

    create_adapter_fn: ?WintunCreateAdapterFn = null,
    open_adapter_fn: ?WintunOpenAdapterFn = null,
    close_adapter_fn: ?WintunCloseAdapterFn = null,
    start_session_fn: ?WintunStartSessionFn = null,
    end_session_fn: ?WintunEndSessionFn = null,
    receive_packet_fn: ?WintunReceivePacketFn = null,
    release_receive_packet_fn: ?WintunReleaseReceivePacketFn = null,
    allocate_send_packet_fn: ?WintunAllocateSendPacketFn = null,
    send_packet_fn: ?WintunSendPacketFn = null,

    pub fn init(allocator: std.mem.Allocator, adapter_name: []const u8) !WintunDevice {
        _ = allocator;
        _ = adapter_name;
        var dev = WintunDevice{};
        if (builtin.os.tag != .windows) return dev;

        dev.lib = std.DynLib.open("wintun.dll") catch return dev;

        if (dev.lib) |*lib| {
            dev.create_adapter_fn = lib.lookup(WintunCreateAdapterFn, "WintunCreateAdapter");
            dev.open_adapter_fn = lib.lookup(WintunOpenAdapterFn, "WintunOpenAdapter");
            dev.close_adapter_fn = lib.lookup(WintunCloseAdapterFn, "WintunCloseAdapter");
            dev.start_session_fn = lib.lookup(WintunStartSessionFn, "WintunStartSession");
            dev.end_session_fn = lib.lookup(WintunEndSessionFn, "WintunEndSession");
            dev.receive_packet_fn = lib.lookup(WintunReceivePacketFn, "WintunReceivePacket");
            dev.release_receive_packet_fn = lib.lookup(WintunReleaseReceivePacketFn, "WintunReleaseReceivePacket");
            dev.allocate_send_packet_fn = lib.lookup(WintunAllocateSendPacketFn, "WintunAllocateSendPacket");
            dev.send_packet_fn = lib.lookup(WintunSendPacketFn, "WintunSendPacket");
        }

        return dev;
    }

    pub fn deinit(self: *WintunDevice) void {
        if (self.session) |sess| {
            if (self.end_session_fn) |end_fn| end_fn(sess);
            self.session = null;
        }
        if (self.adapter) |ad| {
            if (self.close_adapter_fn) |close_fn| close_fn(ad);
            self.adapter = null;
        }
        if (self.lib) |*lib| {
            lib.close();
            self.lib = null;
        }
    }

    pub fn readPacket(self: *WintunDevice, buf: []u8) !usize {
        const sess = self.session orelse return 0;
        const recv_fn = self.receive_packet_fn orelse return 0;
        const rel_fn = self.release_receive_packet_fn orelse return 0;

        var pkt_size: u32 = 0;
        const pkt_ptr = recv_fn(sess, &pkt_size) orelse return 0;
        defer rel_fn(sess, pkt_ptr);

        const copy_len = @min(buf.len, pkt_size);
        @memcpy(buf[0..copy_len], pkt_ptr[0..copy_len]);
        return copy_len;
    }

    pub fn writePacket(self: *WintunDevice, buf: []const u8) !usize {
        const sess = self.session orelse return buf.len;
        const alloc_fn = self.allocate_send_packet_fn orelse return buf.len;
        const send_fn = self.send_packet_fn orelse return buf.len;

        const pkt_ptr = alloc_fn(sess, @intCast(buf.len)) orelse return error.BufferTooSmall;
        @memcpy(pkt_ptr[0..buf.len], buf);
        send_fn(sess, pkt_ptr);
        return buf.len;
    }
};
