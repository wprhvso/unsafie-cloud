const std = @import("std");
const learner_mod = @import("learner.zig");

pub const Cidr = struct {
    net: u32,
    mask: u32,

    pub fn matches(self: Cidr, ip: u32) bool {
        return (ip & self.mask) == (self.net & self.mask);
    }
};

pub fn parseIpv4(str: []const u8) ?u32 {
    var parts = std.mem.splitScalar(u8, str, '.');
    var result: u32 = 0;
    var count: usize = 0;
    while (parts.next()) |p| : (count += 1) {
        if (count >= 4) return null;
        const b = std.fmt.parseInt(u8, p, 10) catch return null;
        result = (result << 8) | @as(u32, b);
    }
    if (count != 4) return null;
    return result;
}

pub fn parseCidr(str: []const u8) ?Cidr {
    const slash = std.mem.indexOfScalar(u8, str, '/') orelse {
        const ip = parseIpv4(str) orelse return null;
        return Cidr{ .net = ip, .mask = 0xffffffff };
    };
    const ip_str = str[0..slash];
    const prefix_str = str[slash + 1 ..];
    const ip = parseIpv4(ip_str) orelse return null;
    const prefix = std.fmt.parseInt(u8, prefix_str, 10) catch return null;
    if (prefix == 0) return Cidr{ .net = 0, .mask = 0 };
    if (prefix >= 32) return Cidr{ .net = ip, .mask = 0xffffffff };
    const shift: u5 = @intCast(32 - prefix);
    const mask = ~(@as(u32, 0)) << shift;
    return Cidr{ .net = ip, .mask = mask };
}

pub const RouteAction = enum {
    direct,
    mesh,
    drop,
};

pub const SmartRouter = struct {
    allocator: std.mem.Allocator,
    direct_cidrs: std.ArrayList(Cidr),
    direct_domains: std.ArrayList([]const u8),
    blocked_domains: std.ArrayList([]const u8),
    routed_domains: std.ArrayList([]const u8),
    mesh_subnet: Cidr,
    default_mesh: bool,
    learner: *learner_mod.LearnerSet,

    pub fn init(allocator: std.mem.Allocator, learner: *learner_mod.LearnerSet, default_action: []const u8, mesh_sub: []const u8) SmartRouter {
        return .{
            .allocator = allocator,
            .direct_cidrs = std.ArrayList(Cidr){},
            .direct_domains = std.ArrayList([]const u8){},
            .blocked_domains = std.ArrayList([]const u8){},
            .routed_domains = std.ArrayList([]const u8){},
            .mesh_subnet = parseCidr(mesh_sub) orelse Cidr{ .net = 0x0a2a0000, .mask = 0xffff0000 },
            .default_mesh = std.mem.eql(u8, default_action, "tunnel") or std.mem.eql(u8, default_action, "mesh"),
            .learner = learner,
        };
    }

    pub fn deinit(self: *SmartRouter) void {
        self.direct_cidrs.deinit(self.allocator);
        self.direct_domains.deinit(self.allocator);
        self.blocked_domains.deinit(self.allocator);
        self.routed_domains.deinit(self.allocator);
    }

    pub fn addDirectCidr(self: *SmartRouter, cidr_str: []const u8) !void {
        if (parseCidr(cidr_str)) |c| {
            try self.direct_cidrs.append(self.allocator, c);
        }
    }

    pub fn addDirectDomain(self: *SmartRouter, d: []const u8) !void {
        try self.direct_domains.append(self.allocator, d);
    }

    pub fn addBlockedDomain(self: *SmartRouter, d: []const u8) !void {
        try self.blocked_domains.append(self.allocator, d);
    }

    pub fn addRoutedDomain(self: *SmartRouter, d: []const u8) !void {
        try self.routed_domains.append(self.allocator, d);
    }

    pub fn matchesDomain(pattern: []const u8, domain: []const u8) bool {
        if (pattern.len > 1 and pattern[0] == '*' and pattern[1] == '.') {
            const suffix = pattern[1..];
            return std.mem.endsWith(u8, domain, suffix);
        }
        return std.mem.eql(u8, pattern, domain) or (pattern.len > 0 and pattern[0] == '.' and std.mem.endsWith(u8, domain, pattern));
    }

    pub fn decide(self: *const SmartRouter, dst_ip: u32, domain: ?[]const u8) RouteAction {
        if ((dst_ip >> 24) == 127) return .direct;

        for (self.direct_cidrs.items) |c| {
            if (c.matches(dst_ip)) return .direct;
        }

        if (domain) |d| {
            for (self.blocked_domains.items) |pattern| {
                if (matchesDomain(pattern, d)) return .drop;
            }
            for (self.direct_domains.items) |pattern| {
                if (matchesDomain(pattern, d)) {
                    self.learner.learn(dst_ip) catch {};
                    return .direct;
                }
            }
            for (self.routed_domains.items) |pattern| {
                if (matchesDomain(pattern, d)) return .mesh;
            }
        }

        if (self.learner.has(dst_ip)) return .direct;

        if (self.mesh_subnet.matches(dst_ip)) return .mesh;

        return if (self.default_mesh) .mesh else .direct;
    }
};
