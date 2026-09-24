const std = @import("std");

pub const MetadataConfig = struct {
    version: u32 = 1,
    timestamp: i64 = 0,
    updated_by: []const u8 = "unsafie-node",
};

pub const NodeConfig = struct {
    name: []const u8 = "unsafie-node",
    role: []const u8 = "admin",
    private_key: []const u8 = "",
    listen_port: u16 = 51820,
    vpn_ip: []const u8 = "10.42.0.1",
    vpn_subnet: []const u8 = "10.42.0.0/16",
    vpn_iface: []const u8 = "unsafie0",
    mtu: u32 = 1420,
};

pub const AmneziaConfig = struct {
    jc: u32 = 4,
    jmin: u32 = 40,
    jmax: u32 = 70,
    s1: u32 = 64,
    s2: u32 = 48,
    h1: u32 = 1287634912,
    h2: u32 = 837194625,
    h3: u32 = 1092837465,
    h4: u32 = 1982736450,
    psk: []const u8 = "",
};

pub const RoleConfig = struct {
    name: []const u8 = "",
    permissions: [][]const u8 = &[_][]const u8{},
};

pub const PeerConfig = struct {
    name: []const u8 = "",
    role: []const u8 = "client",
    public_key: []const u8 = "",
    endpoint: []const u8 = "",
    allowed_ips: [][]const u8 = &[_][]const u8{},
    can_sync_config: bool = false,
    persistent_keepalive: u32 = 25,
};

pub const HostRecord = struct {
    name: []const u8 = "",
    ip: []const u8 = "",
};

pub const RoutingConfig = struct {
    default_action: []const u8 = "tunnel",
    direct_domains: [][]const u8 = &[_][]const u8{},
    direct_cidrs: [][]const u8 = &[_][]const u8{},
    blocked_domains: [][]const u8 = &[_][]const u8{},
    routed_domains: [][]const u8 = &[_][]const u8{},
};

pub const DnsConfig = struct {
    listen: []const u8 = "10.42.0.1:53",
    upstreams: [][]const u8 = &[_][]const u8{},
    hosts: []HostRecord = &[_]HostRecord{},
};

pub const FullConfig = struct {
    arena: *std.heap.ArenaAllocator,
    metadata: MetadataConfig = .{},
    node: NodeConfig = .{},
    amnezia: AmneziaConfig = .{},
    roles: []RoleConfig = &[_]RoleConfig{},
    peers: []PeerConfig = &[_]PeerConfig{},
    routing: RoutingConfig = .{},
    dns: DnsConfig = .{},

    pub fn deinit(self: *FullConfig) void {
        const backing = self.arena.child_allocator;
        self.arena.deinit();
        backing.destroy(self.arena);
    }

    pub fn serialize(self: *const FullConfig, writer: anytype) !void {
        try writer.print(
            \\metadata:
            \\  version: {d}
            \\  timestamp: {d}
            \\  updated_by: "{s}"
            \\
            \\node:
            \\  name: "{s}"
            \\  role: "{s}"
            \\  private_key: "{s}"
            \\  listen_port: {d}
            \\  vpn_ip: "{s}"
            \\  vpn_subnet: "{s}"
            \\  vpn_iface: "{s}"
            \\  mtu: {d}
            \\
            \\amnezia:
            \\  jc: {d}
            \\  jmin: {d}
            \\  jmax: {d}
            \\  s1: {d}
            \\  s2: {d}
            \\  h1: {d}
            \\  h2: {d}
            \\  h3: {d}
            \\  h4: {d}
            \\  psk: "{s}"
            \\
            \\roles:
            \\
        , .{
            self.metadata.version,
            self.metadata.timestamp,
            self.metadata.updated_by,
            self.node.name,
            self.node.role,
            self.node.private_key,
            self.node.listen_port,
            self.node.vpn_ip,
            self.node.vpn_subnet,
            self.node.vpn_iface,
            self.node.mtu,
            self.amnezia.jc,
            self.amnezia.jmin,
            self.amnezia.jmax,
            self.amnezia.s1,
            self.amnezia.s2,
            self.amnezia.h1,
            self.amnezia.h2,
            self.amnezia.h3,
            self.amnezia.h4,
            self.amnezia.psk,
        });

        for (self.roles) |r| {
            try writer.print("  - name: \"{s}\"\n    permissions:\n", .{r.name});
            for (r.permissions) |p| {
                try writer.print("      - \"{s}\"\n", .{p});
            }
        }

        try writer.writeAll("\npeers:\n");
        for (self.peers) |p| {
            try writer.print(
                \\  - name: "{s}"
                \\    role: "{s}"
                \\    public_key: "{s}"
                \\    endpoint: "{s}"
                \\    can_sync_config: {s}
                \\    persistent_keepalive: {d}
                \\    allowed_ips:
                \\
            , .{
                p.name,
                p.role,
                p.public_key,
                p.endpoint,
                if (p.can_sync_config) "true" else "false",
                p.persistent_keepalive,
            });
            for (p.allowed_ips) |ip| {
                try writer.print("      - \"{s}\"\n", .{ip});
            }
        }

        try writer.print(
            \\
            \\routing:
            \\  default_action: "{s}"
            \\  direct_domains:
            \\
        , .{self.routing.default_action});
        for (self.routing.direct_domains) |d| {
            try writer.print("    - \"{s}\"\n", .{d});
        }

        try writer.writeAll("  direct_cidrs:\n");
        for (self.routing.direct_cidrs) |c| {
            try writer.print("    - \"{s}\"\n", .{c});
        }

        try writer.writeAll("  blocked_domains:\n");
        for (self.routing.blocked_domains) |b| {
            try writer.print("    - \"{s}\"\n", .{b});
        }

        try writer.writeAll("  routed_domains:\n");
        for (self.routing.routed_domains) |rd| {
            try writer.print("    - \"{s}\"\n", .{rd});
        }

        try writer.print(
            \\
            \\dns:
            \\  listen: "{s}"
            \\  upstreams:
            \\
        , .{self.dns.listen});
        for (self.dns.upstreams) |u| {
            try writer.print("    - \"{s}\"\n", .{u});
        }

        try writer.writeAll("  hosts:\n");
        for (self.dns.hosts) |h| {
            try writer.print("    - name: \"{s}\"\n      ip: \"{s}\"\n", .{ h.name, h.ip });
        }
    }

    pub fn saveToFile(self: *const FullConfig, path: []const u8) !void {
        const file = try std.fs.cwd().createFile(path, .{ .truncate = true });
        defer file.close();
        var buf = std.ArrayList(u8){};
        defer buf.deinit(std.heap.page_allocator);
        try self.serialize(buf.writer(std.heap.page_allocator));
        try file.writeAll(buf.items);
    }

    pub fn hasPermission(self: *const FullConfig, role_name: []const u8, permission: []const u8) bool {
        if (std.mem.eql(u8, role_name, "admin")) return true;
        for (self.roles) |r| {
            if (std.mem.eql(u8, r.name, role_name)) {
                for (r.permissions) |p| {
                    if (std.mem.eql(u8, p, permission) or std.mem.eql(u8, p, "*")) return true;
                }
            }
        }
        return false;
    }

    pub fn isPeerAuthorizedToSync(self: *const FullConfig, peer_pubkey: []const u8) bool {
        for (self.peers) |p| {
            if (std.mem.eql(u8, p.public_key, peer_pubkey)) {
                if (p.can_sync_config) return true;
                if (self.hasPermission(p.role, "sync_config")) return true;
            }
        }
        return false;
    }
};

const KeyVal = struct {
    key: []const u8,
    val: []const u8,
};

fn findKv(line: []const u8) ?KeyVal {
    const colon_idx = std.mem.indexOfScalar(u8, line, ':') orelse return null;
    const key = std.mem.trim(u8, line[0..colon_idx], " \t-");
    const val = std.mem.trim(u8, line[colon_idx + 1 ..], " \t");
    return KeyVal{ .key = key, .val = val };
}

fn countIndent(line: []const u8) usize {
    var count: usize = 0;
    for (line) |c| {
        if (c == ' ') {
            count += 1;
        } else if (c == '\t') {
            count += 2;
        } else {
            break;
        }
    }
    return count;
}

fn cleanVal(val: []const u8) []const u8 {
    var v = std.mem.trim(u8, val, " \t\r");
    if (v.len >= 2 and ((v[0] == '"' and v[v.len - 1] == '"') or (v[0] == '\'' and v[v.len - 1] == '\''))) {
        v = v[1 .. v.len - 1];
    }
    return v;
}

pub fn parseYaml(allocator: std.mem.Allocator, input: []const u8) !FullConfig {
    const arena_ptr = try allocator.create(std.heap.ArenaAllocator);
    arena_ptr.* = std.heap.ArenaAllocator.init(allocator);
    errdefer {
        arena_ptr.deinit();
        allocator.destroy(arena_ptr);
    }
    const a = arena_ptr.allocator();

    var cfg = FullConfig{ .arena = arena_ptr };

    var roles_list = std.ArrayList(RoleConfig){};
    var peers_list = std.ArrayList(PeerConfig){};
    var direct_domains = std.ArrayList([]const u8){};
    var direct_cidrs = std.ArrayList([]const u8){};
    var blocked_domains = std.ArrayList([]const u8){};
    var routed_domains = std.ArrayList([]const u8){};
    var upstreams = std.ArrayList([]const u8){};
    var hosts_list = std.ArrayList(HostRecord){};

    var current_section: []const u8 = "";
    var current_subsection: []const u8 = "";

    var lines = std.mem.splitScalar(u8, input, '\n');
    while (lines.next()) |raw_line| {
        const line = std.mem.trim(u8, raw_line, " \r\t");
        if (line.len == 0 or line[0] == '#') continue;

        const indent = countIndent(raw_line);

        if (indent == 0 and std.mem.endsWith(u8, line, ":")) {
            current_section = line[0 .. line.len - 1];
            current_subsection = "";
            continue;
        }

        if (std.mem.eql(u8, current_section, "metadata")) {
            if (findKv(line)) |kv| {
                if (std.mem.eql(u8, kv.key, "version")) {
                    cfg.metadata.version = std.fmt.parseInt(u32, kv.val, 10) catch 1;
                } else if (std.mem.eql(u8, kv.key, "timestamp")) {
                    cfg.metadata.timestamp = std.fmt.parseInt(i64, kv.val, 10) catch 0;
                } else if (std.mem.eql(u8, kv.key, "updated_by")) {
                    cfg.metadata.updated_by = try a.dupe(u8, cleanVal(kv.val));
                }
            }
        } else if (std.mem.eql(u8, current_section, "node")) {
            if (findKv(line)) |kv| {
                if (std.mem.eql(u8, kv.key, "name")) {
                    cfg.node.name = try a.dupe(u8, cleanVal(kv.val));
                } else if (std.mem.eql(u8, kv.key, "role")) {
                    cfg.node.role = try a.dupe(u8, cleanVal(kv.val));
                } else if (std.mem.eql(u8, kv.key, "private_key")) {
                    cfg.node.private_key = try a.dupe(u8, cleanVal(kv.val));
                } else if (std.mem.eql(u8, kv.key, "listen_port")) {
                    cfg.node.listen_port = std.fmt.parseInt(u16, kv.val, 10) catch 51820;
                } else if (std.mem.eql(u8, kv.key, "vpn_ip")) {
                    cfg.node.vpn_ip = try a.dupe(u8, cleanVal(kv.val));
                } else if (std.mem.eql(u8, kv.key, "vpn_subnet")) {
                    cfg.node.vpn_subnet = try a.dupe(u8, cleanVal(kv.val));
                } else if (std.mem.eql(u8, kv.key, "vpn_iface")) {
                    cfg.node.vpn_iface = try a.dupe(u8, cleanVal(kv.val));
                } else if (std.mem.eql(u8, kv.key, "mtu")) {
                    cfg.node.mtu = std.fmt.parseInt(u32, kv.val, 10) catch 1420;
                }
            }
        } else if (std.mem.eql(u8, current_section, "amnezia")) {
            if (findKv(line)) |kv| {
                if (std.mem.eql(u8, kv.key, "jc")) {
                    cfg.amnezia.jc = std.fmt.parseInt(u32, kv.val, 10) catch 4;
                } else if (std.mem.eql(u8, kv.key, "jmin")) {
                    cfg.amnezia.jmin = std.fmt.parseInt(u32, kv.val, 10) catch 40;
                } else if (std.mem.eql(u8, kv.key, "jmax")) {
                    cfg.amnezia.jmax = std.fmt.parseInt(u32, kv.val, 10) catch 70;
                } else if (std.mem.eql(u8, kv.key, "s1")) {
                    cfg.amnezia.s1 = std.fmt.parseInt(u32, kv.val, 10) catch 64;
                } else if (std.mem.eql(u8, kv.key, "s2")) {
                    cfg.amnezia.s2 = std.fmt.parseInt(u32, kv.val, 10) catch 48;
                } else if (std.mem.eql(u8, kv.key, "h1")) {
                    cfg.amnezia.h1 = std.fmt.parseInt(u32, kv.val, 10) catch 1287634912;
                } else if (std.mem.eql(u8, kv.key, "h2")) {
                    cfg.amnezia.h2 = std.fmt.parseInt(u32, kv.val, 10) catch 837194625;
                } else if (std.mem.eql(u8, kv.key, "h3")) {
                    cfg.amnezia.h3 = std.fmt.parseInt(u32, kv.val, 10) catch 1092837465;
                } else if (std.mem.eql(u8, kv.key, "h4")) {
                    cfg.amnezia.h4 = std.fmt.parseInt(u32, kv.val, 10) catch 1982736450;
                } else if (std.mem.eql(u8, kv.key, "psk")) {
                    cfg.amnezia.psk = try a.dupe(u8, cleanVal(kv.val));
                }
            }
        } else if (std.mem.eql(u8, current_section, "roles")) {
            if (std.mem.startsWith(u8, line, "- ")) {
                const sub = std.mem.trim(u8, line[2..], " ");
                var role_entry = RoleConfig{};
                if (findKv(sub)) |kv| {
                    if (std.mem.eql(u8, kv.key, "name")) {
                        role_entry.name = try a.dupe(u8, cleanVal(kv.val));
                    }
                }
                try roles_list.append(a, role_entry);
            } else if (findKv(line)) |kv| {
                if (std.mem.eql(u8, kv.key, "name") and roles_list.items.len > 0) {
                    roles_list.items[roles_list.items.len - 1].name = try a.dupe(u8, cleanVal(kv.val));
                } else if (std.mem.eql(u8, kv.key, "permissions")) {
                    current_subsection = "permissions";
                }
            } else if (std.mem.startsWith(u8, line, "- ") and roles_list.items.len > 0) {
                const perm = try a.dupe(u8, cleanVal(line[2..]));
                const last_idx = roles_list.items.len - 1;
                var current_perms = std.ArrayList([]const u8){};
                for (roles_list.items[last_idx].permissions) |p| {
                    try current_perms.append(a, p);
                }
                try current_perms.append(a, perm);
                roles_list.items[last_idx].permissions = try current_perms.toOwnedSlice(a);
            }
        } else if (std.mem.eql(u8, current_section, "peers")) {
            if (std.mem.startsWith(u8, line, "- ")) {
                const sub = std.mem.trim(u8, line[2..], " ");
                var peer_entry = PeerConfig{};
                if (findKv(sub)) |kv| {
                    if (std.mem.eql(u8, kv.key, "name")) {
                        peer_entry.name = try a.dupe(u8, cleanVal(kv.val));
                    }
                }
                try peers_list.append(a, peer_entry);
            } else if (findKv(line)) |kv| {
                if (peers_list.items.len > 0) {
                    const last_idx = peers_list.items.len - 1;
                    if (std.mem.eql(u8, kv.key, "name")) {
                        peers_list.items[last_idx].name = try a.dupe(u8, cleanVal(kv.val));
                    } else if (std.mem.eql(u8, kv.key, "role")) {
                        peers_list.items[last_idx].role = try a.dupe(u8, cleanVal(kv.val));
                    } else if (std.mem.eql(u8, kv.key, "public_key")) {
                        peers_list.items[last_idx].public_key = try a.dupe(u8, cleanVal(kv.val));
                    } else if (std.mem.eql(u8, kv.key, "endpoint")) {
                        peers_list.items[last_idx].endpoint = try a.dupe(u8, cleanVal(kv.val));
                    } else if (std.mem.eql(u8, kv.key, "can_sync_config")) {
                        peers_list.items[last_idx].can_sync_config = std.mem.eql(u8, cleanVal(kv.val), "true");
                    } else if (std.mem.eql(u8, kv.key, "persistent_keepalive")) {
                        peers_list.items[last_idx].persistent_keepalive = std.fmt.parseInt(u32, kv.val, 10) catch 25;
                    } else if (std.mem.eql(u8, kv.key, "allowed_ips")) {
                        current_subsection = "allowed_ips";
                    }
                }
            } else if (std.mem.startsWith(u8, line, "- ") and peers_list.items.len > 0) {
                const ip = try a.dupe(u8, cleanVal(line[2..]));
                const last_idx = peers_list.items.len - 1;
                var ips = std.ArrayList([]const u8){};
                for (peers_list.items[last_idx].allowed_ips) |existing_ip| {
                    try ips.append(a, existing_ip);
                }
                try ips.append(a, ip);
                peers_list.items[last_idx].allowed_ips = try ips.toOwnedSlice(a);
            }
        } else if (std.mem.eql(u8, current_section, "routing")) {
            if (findKv(line)) |kv| {
                if (std.mem.eql(u8, kv.key, "default_action")) {
                    cfg.routing.default_action = try a.dupe(u8, cleanVal(kv.val));
                } else if (std.mem.eql(u8, kv.key, "direct_domains")) {
                    current_subsection = "direct_domains";
                } else if (std.mem.eql(u8, kv.key, "direct_cidrs")) {
                    current_subsection = "direct_cidrs";
                } else if (std.mem.eql(u8, kv.key, "blocked_domains")) {
                    current_subsection = "blocked_domains";
                } else if (std.mem.eql(u8, kv.key, "routed_domains")) {
                    current_subsection = "routed_domains";
                }
            } else if (std.mem.startsWith(u8, line, "- ")) {
                const val = try a.dupe(u8, cleanVal(line[2..]));
                if (std.mem.eql(u8, current_subsection, "direct_domains")) {
                    try direct_domains.append(a, val);
                } else if (std.mem.eql(u8, current_subsection, "direct_cidrs")) {
                    try direct_cidrs.append(a, val);
                } else if (std.mem.eql(u8, current_subsection, "blocked_domains")) {
                    try blocked_domains.append(a, val);
                } else if (std.mem.eql(u8, current_subsection, "routed_domains")) {
                    try routed_domains.append(a, val);
                }
            }
        } else if (std.mem.eql(u8, current_section, "dns")) {
            if (findKv(line)) |kv| {
                if (std.mem.eql(u8, kv.key, "listen")) {
                    cfg.dns.listen = try a.dupe(u8, cleanVal(kv.val));
                } else if (std.mem.eql(u8, kv.key, "upstreams")) {
                    current_subsection = "upstreams";
                } else if (std.mem.eql(u8, kv.key, "hosts")) {
                    current_subsection = "hosts";
                }
            } else if (std.mem.startsWith(u8, line, "- ")) {
                const sub = std.mem.trim(u8, line[2..], " ");
                if (findKv(sub)) |kv| {
                    if (std.mem.eql(u8, kv.key, "name")) {
                        try hosts_list.append(a, .{
                            .name = try a.dupe(u8, cleanVal(kv.val)),
                            .ip = "",
                        });
                    }
                } else {
                    const val = try a.dupe(u8, cleanVal(line[2..]));
                    if (std.mem.eql(u8, current_subsection, "upstreams")) {
                        try upstreams.append(a, val);
                    }
                }
            } else if (hosts_list.items.len > 0 and std.mem.eql(u8, current_subsection, "hosts")) {
                if (findKv(line)) |kv| {
                    if (std.mem.eql(u8, kv.key, "ip")) {
                        hosts_list.items[hosts_list.items.len - 1].ip = try a.dupe(u8, cleanVal(kv.val));
                    }
                }
            }
        }
    }

    cfg.roles = try roles_list.toOwnedSlice(a);
    cfg.peers = try peers_list.toOwnedSlice(a);
    cfg.routing.direct_domains = try direct_domains.toOwnedSlice(a);
    cfg.routing.direct_cidrs = try direct_cidrs.toOwnedSlice(a);
    cfg.routing.blocked_domains = try blocked_domains.toOwnedSlice(a);
    cfg.routing.routed_domains = try routed_domains.toOwnedSlice(a);
    cfg.dns.upstreams = try upstreams.toOwnedSlice(a);
    cfg.dns.hosts = try hosts_list.toOwnedSlice(a);

    return cfg;
}

pub fn loadFromFile(allocator: std.mem.Allocator, path: []const u8) !FullConfig {
    const file = try std.fs.cwd().openFile(path, .{ .mode = .read_only });
    defer file.close();

    const max_size = 10 * 1024 * 1024;
    const content = try file.readToEndAlloc(allocator, max_size);
    defer allocator.free(content);

    return parseYaml(allocator, content);
}
