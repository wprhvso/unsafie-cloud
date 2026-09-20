const std = @import("std");
const learner = @import("learner.zig");
const rules = @import("rules.zig");
const ipam = @import("ipam.zig");

pub const DnsServer = struct {
    allocator: std.mem.Allocator,
    records: std.StringHashMap(u32),
    learner_set: *learner.LearnerSet,
    rules_engine: *const rules.RulesEngine,
    running: bool = false,

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
            .running = false,
        };
    }

    pub fn deinit(self: *DnsServer) void {
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
        _ = port;
        self.running = true;
    }
};
