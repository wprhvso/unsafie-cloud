const std = @import("std");
const tun = @import("tun.zig");
const ipam = @import("ipam.zig");
const learner = @import("learner.zig");
const rules = @import("rules.zig");
const dns = @import("dns.zig");
const router = @import("router.zig");
const telemetry = @import("mesh/telemetry.zig");
const pathfinder = @import("mesh/pathfinder.zig");
const relay = @import("mesh/relay.zig");

pub const VpnService = struct {
    allocator: std.mem.Allocator,
    tun_dev: tun.TunDevice,
    ipam_mgr: ipam.Ipam,
    learner_set: learner.LearnerSet,
    rules_engine: rules.RulesEngine,
    dns_server: dns.DnsServer,
    telem: telemetry.MeshTelemetry,
    pf: pathfinder.Pathfinder,
    blind_relay: relay.BlindRelay,
    l3_router: router.Router,

    pub fn init(allocator: std.mem.Allocator, ifname: []const u8, subnet: []const u8) !*VpnService {
        const self = try allocator.create(VpnService);
        errdefer allocator.destroy(self);

        self.allocator = allocator;
        self.tun_dev = try tun.TunDevice.init(allocator, ifname);
        self.ipam_mgr = ipam.Ipam.init(allocator, subnet);
        self.learner_set = learner.LearnerSet.init(allocator);
        self.rules_engine = rules.RulesEngine.init(allocator);
        self.dns_server = dns.DnsServer.init(allocator, &self.learner_set, &self.rules_engine);
        self.telem = telemetry.MeshTelemetry.init(allocator);
        self.pf = pathfinder.Pathfinder.init(allocator, &self.telem);
        self.blind_relay = relay.BlindRelay.init(allocator);
        self.l3_router = router.Router.init(allocator, &self.learner_set, &self.rules_engine, &self.pf);

        try self.dns_server.start(53);
        return self;
    }

    pub fn deinit(self: *VpnService) void {
        self.tun_dev.deinit();
        self.learner_set.deinit();
        self.dns_server.deinit();
        self.telem.deinit();
        self.pf.deinit();
        self.allocator.destroy(self);
    }
};
