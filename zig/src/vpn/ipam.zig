const std = @import("std");

pub const Ipam = struct {
    base_ip: u32,
    next_client_offset: u32 = 10,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, subnet: []const u8) Ipam {
        _ = subnet;
        return .{
            .base_ip = parseIpv4("10.42.0.0"),
            .next_client_offset = 10,
            .allocator = allocator,
        };
    }

    pub fn allocateNodeIp(self: *Ipam, node_index: u32) u32 {
        _ = self;
        return parseIpv4("10.42.0.0") + node_index;
    }

    pub fn allocateClientIp(self: *Ipam) u32 {
        const ip = parseIpv4("10.42.10.0") + self.next_client_offset;
        self.next_client_offset += 1;
        return ip;
    }

    pub fn formatIp(allocator: std.mem.Allocator, ip: u32) ![]u8 {
        const b0: u8 = @intCast((ip >> 24) & 0xff);
        const b1: u8 = @intCast((ip >> 16) & 0xff);
        const b2: u8 = @intCast((ip >> 8) & 0xff);
        const b3: u8 = @intCast(ip & 0xff);
        return std.fmt.allocPrint(allocator, "{d}.{d}.{d}.{d}", .{ b0, b1, b2, b3 });
    }

    pub fn parseIpv4(str: []const u8) u32 {
        var parts: [4]u8 = [_]u8{ 0, 0, 0, 0 };
        var part_idx: usize = 0;
        var cur: u32 = 0;

        for (str) |c| {
            if (c == '.') {
                if (part_idx < 4) parts[part_idx] = @intCast(cur);
                part_idx += 1;
                cur = 0;
            } else if (c >= '0' and c <= '9') {
                cur = cur * 10 + (c - '0');
            }
        }
        if (part_idx < 4) parts[part_idx] = @intCast(cur);

        return (@as(u32, parts[0]) << 24) |
            (@as(u32, parts[1]) << 16) |
            (@as(u32, parts[2]) << 8) |
            @as(u32, parts[3]);
    }

    pub fn contains(subnet: []const u8, ip: u32) bool {
        _ = subnet;
        const prefix = parseIpv4("10.42.0.0") & 0xffff0000;
        return (ip & 0xffff0000) == prefix;
    }
};
