const std = @import("std");
const linux = std.os.linux;

pub const Mode = enum {
    server,
    client,
    admin,
};

pub const MetadataConfig = struct {
    version: u32 = 1,
    timestamp: i64 = 0,
    updated_by: []const u8 = "unsafie",
};

pub const NodeConfig = struct {
    mode: Mode = .server,
    listen_port: u16 = 51820,
    vpn_ip: []const u8 = "10.42.0.1",
    vpn_subnet: []const u8 = "10.42.0.0/16",
    vpn_iface: []const u8 = "unsafie0",
    mtu: u32 = 1420,
    client_token: []const u8 = "",
    admin_token: []const u8 = "",
    token: []const u8 = "",
    servers: [][]const u8 = &[_][]const u8{},
    smart_routing: bool = true,
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

pub const HostRecord = struct {
    name: []const u8 = "",
    ip: []const u8 = "",
};

pub const DnsConfig = struct {
    listen: []const u8 = "10.42.0.1:53",
    upstreams: [][]const u8 = &[_][]const u8{},
    hosts: []HostRecord = &[_]HostRecord{},
};

pub const RoutingConfig = struct {
    default_action: []const u8 = "tunnel",
    direct_domains: [][]const u8 = &[_][]const u8{},
    direct_cidrs: [][]const u8 = &[_][]const u8{},
    blocked_domains: [][]const u8 = &[_][]const u8{},
    routed_domains: [][]const u8 = &[_][]const u8{},
};

pub const FullConfig = struct {
    arena: *std.heap.ArenaAllocator,
    metadata: MetadataConfig = .{},
    node: NodeConfig = .{},
    amnezia: AmneziaConfig = .{},
    routing: RoutingConfig = .{},
    dns: DnsConfig = .{},

    pub fn deinit(self: *FullConfig) void {
        const backing = self.arena.child_allocator;
        self.arena.deinit();
        backing.destroy(self.arena);
    }

    pub fn serialize(self: *const FullConfig, writer: anytype) !void {
        const mode_str = switch (self.node.mode) {
            .server => "server",
            .client => "client",
            .admin => "admin",
        };

        try writer.print(
            \\metadata:
            \\  version: {d}
            \\  timestamp: {d}
            \\  updated_by: "{s}"
            \\
            \\mode: "{s}"
            \\token: "{s}"
            \\client_token: "{s}"
            \\admin_token: "{s}"
            \\smart_routing: {s}
            \\listen_port: {d}
            \\vpn_ip: "{s}"
            \\vpn_subnet: "{s}"
            \\vpn_iface: "{s}"
            \\mtu: {d}
            \\
            \\servers:
            \\
        , .{
            self.metadata.version,
            self.metadata.timestamp,
            self.metadata.updated_by,
            mode_str,
            self.node.token,
            self.node.client_token,
            self.node.admin_token,
            if (self.node.smart_routing) "true" else "false",
            self.node.listen_port,
            self.node.vpn_ip,
            self.node.vpn_subnet,
            self.node.vpn_iface,
            self.node.mtu,
        });

        for (self.node.servers) |s| {
            try writer.print("  - \"{s}\"\n", .{s});
        }

        try writer.print(
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
            \\routing:
            \\  default_action: "{s}"
            \\  direct_domains:
            \\
        , .{
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
            self.routing.default_action,
        });

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
        var path_buf: [1024]u8 = undefined;
        if (path.len >= 1023) return error.PathTooLong;
        @memcpy(path_buf[0..path.len], path);
        path_buf[path.len] = 0;
        const path_z: [*:0]const u8 = @ptrCast(&path_buf);

        const flags = linux.O{ .ACCMODE = .WRONLY, .CREAT = true, .TRUNC = true };
        const fd_rc = linux.open(path_z, flags, 0o644);
        const fd: i32 = @intCast(fd_rc);
        if (fd < 0) return error.CannotCreateFile;
        defer _ = linux.close(fd);

        var buf: std.ArrayList(u8) = .empty;
        defer buf.deinit(std.heap.page_allocator);
        try self.serialize(buf.writer(std.heap.page_allocator));
        _ = linux.write(fd, buf.items.ptr, buf.items.len);
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

    var servers_list: std.ArrayList([]const u8) = .empty;
    var direct_domains: std.ArrayList([]const u8) = .empty;
    var direct_cidrs: std.ArrayList([]const u8) = .empty;
    var blocked_domains: std.ArrayList([]const u8) = .empty;
    var routed_domains: std.ArrayList([]const u8) = .empty;
    var upstreams: std.ArrayList([]const u8) = .empty;
    var hosts_list: std.ArrayList(HostRecord) = .empty;

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

        if (indent == 0) {
            if (findKv(line)) |kv| {
                if (std.mem.eql(u8, kv.key, "mode")) {
                    const m = cleanVal(kv.val);
                    if (std.mem.eql(u8, m, "client")) {
                        cfg.node.mode = .client;
                    } else if (std.mem.eql(u8, m, "admin")) {
                        cfg.node.mode = .admin;
                    } else {
                        cfg.node.mode = .server;
                    }
                } else if (std.mem.eql(u8, kv.key, "token")) {
                    cfg.node.token = try a.dupe(u8, cleanVal(kv.val));
                } else if (std.mem.eql(u8, kv.key, "client_token")) {
                    cfg.node.client_token = try a.dupe(u8, cleanVal(kv.val));
                } else if (std.mem.eql(u8, kv.key, "admin_token")) {
                    cfg.node.admin_token = try a.dupe(u8, cleanVal(kv.val));
                } else if (std.mem.eql(u8, kv.key, "smart_routing")) {
                    cfg.node.smart_routing = !std.mem.eql(u8, cleanVal(kv.val), "false");
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
        } else if (std.mem.eql(u8, current_section, "servers")) {
            if (std.mem.startsWith(u8, line, "- ")) {
                const s = try a.dupe(u8, cleanVal(line[2..]));
                try servers_list.append(a, s);
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

    if (servers_list.items.len > 0 and cfg.node.mode == .server) {
        cfg.node.mode = .client;
    }

    cfg.node.servers = try servers_list.toOwnedSlice(a);
    cfg.routing.direct_domains = try direct_domains.toOwnedSlice(a);
    cfg.routing.direct_cidrs = try direct_cidrs.toOwnedSlice(a);
    cfg.routing.blocked_domains = try blocked_domains.toOwnedSlice(a);
    cfg.routing.routed_domains = try routed_domains.toOwnedSlice(a);
    cfg.dns.upstreams = try upstreams.toOwnedSlice(a);
    cfg.dns.hosts = try hosts_list.toOwnedSlice(a);

    return cfg;
}

pub fn loadFromFile(allocator: std.mem.Allocator, path: []const u8) !FullConfig {
    var path_buf: [1024]u8 = undefined;
    if (path.len >= 1023) return error.PathTooLong;
    @memcpy(path_buf[0..path.len], path);
    path_buf[path.len] = 0;
    const path_z: [*:0]const u8 = @ptrCast(&path_buf);

    const fd_rc = linux.open(path_z, .{}, 0);
    const fd: i32 = @intCast(fd_rc);
    if (fd < 0) return error.FileNotFound;
    defer _ = linux.close(fd);

    var buf = try allocator.alloc(u8, 65536);
    defer allocator.free(buf);

    const n = linux.read(fd, buf.ptr, buf.len);
    if (n < 0) return error.ReadFailed;
    return parseYaml(allocator, buf[0..@intCast(n)]);
}
