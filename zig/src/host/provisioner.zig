const std = @import("std");
const netlink = @import("../vpn/platform/netlink.zig");
const ipam = @import("../vpn/ipam.zig");

pub const HostProvisioner = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) HostProvisioner {
        return .{ .allocator = allocator };
    }

    fn writeProc(path: [*:0]const u8, val: []const u8) void {
        const flags: std.posix.O = .{ .ACCMODE = .WRONLY };
        const rc = std.posix.system.open(path, flags, @as(std.posix.mode_t, 0));
        if (std.posix.errno(rc) != .SUCCESS) return;
        const fd: std.posix.fd_t = @intCast(rc);
        defer std.posix.close(fd);
        _ = std.posix.write(fd, val) catch {};
    }

    fn writeFileSafe(path: [*:0]const u8, data: []const u8) void {
        const flags: std.posix.O = .{ .ACCMODE = .WRONLY, .CREAT = true, .TRUNC = true };
        const rc = std.posix.system.open(path, flags, @as(std.posix.mode_t, 0o644));
        if (std.posix.errno(rc) != .SUCCESS) return;
        const fd: std.posix.fd_t = @intCast(rc);
        defer std.posix.close(fd);
        _ = std.posix.write(fd, data) catch {};
    }

    pub fn ensureSysctl(self: HostProvisioner) !void {
        _ = self;
        writeProc("/proc/sys/net/ipv4/ip_forward", "1\n");
        writeProc("/proc/sys/net/ipv6/conf/all/forwarding", "1\n");
        writeProc("/proc/sys/net/core/default_qdisc", "fq\n");
        writeProc("/proc/sys/net/ipv4/tcp_congestion_control", "bbr\n");
        writeProc("/proc/sys/net/ipv4/tcp_fin_timeout", "15\n");
        writeProc("/proc/sys/net/ipv4/tcp_tw_reuse", "1\n");
        writeProc("/proc/sys/net/core/rmem_max", "16777216\n");
        writeProc("/proc/sys/net/core/wmem_max", "16777216\n");
        writeProc("/proc/sys/vm/swappiness", "10\n");
        writeProc("/proc/sys/vm/overcommit_memory", "1\n");

        const config_data =
            \\net.core.default_qdisc=fq
            \\net.ipv4.tcp_congestion_control=bbr
            \\net.ipv4.tcp_fin_timeout=15
            \\net.ipv4.tcp_tw_reuse=1
            \\net.core.rmem_max=16777216
            \\net.core.wmem_max=16777216
            \\vm.swappiness=10
            \\vm.overcommit_memory=1
            \\net.ipv4.ip_forward=1
            \\net.ipv6.conf.all.forwarding=1
            \\
        ;

        std.fs.cwd().makePath("/etc/sysctl.d") catch {};
        writeFileSafe("/etc/sysctl.d/99-unsafie-cloud.conf", config_data);

        var child = std.process.Child.init(&[_][]const u8{ "sysctl", "-p", "/etc/sysctl.d/99-unsafie-cloud.conf" }, std.heap.page_allocator);
        _ = child.spawnAndWait() catch {};
    }

    pub fn ensurePackages(self: HostProvisioner) !void {
        _ = self;
        const managers = [_][]const []const u8{
            &[_][]const u8{ "apt-get", "install", "-y", "--no-install-recommends", "curl", "htop", "git", "jq", "tmux", "tar", "unzip", "ca-certificates", "iptables" },
            &[_][]const u8{ "dnf", "install", "-y", "curl", "htop", "git", "jq", "tmux", "tar", "unzip", "ca-certificates", "iptables" },
            &[_][]const u8{ "yum", "install", "-y", "curl", "htop", "git", "jq", "tmux", "tar", "unzip", "ca-certificates", "iptables" },
            &[_][]const u8{ "apk", "add", "--no-cache", "curl", "htop", "git", "jq", "tmux", "tar", "unzip", "ca-certificates", "iptables" },
            &[_][]const u8{ "pacman", "-Sy", "--noconfirm", "curl", "htop", "git", "jq", "tmux", "tar", "unzip", "ca-certificates", "iptables" },
            &[_][]const u8{ "zypper", "install", "-y", "curl", "htop", "git", "jq", "tmux", "tar", "unzip", "ca-certificates", "iptables" },
        };

        for (managers) |cmd_slice| {
            var child = std.process.Child.init(cmd_slice, std.heap.page_allocator);
            if (child.spawnAndWait()) |_| {
                break;
            } else |_| {}
        }
    }

    fn findTool(name: []const u8) []const u8 {
        const candidates = [_][]const u8{
            "/run/current-system/sw/bin",
            "/run/wrappers/bin",
            "/nix/var/nix/profiles/default/bin",
            "/usr/local/sbin",
            "/usr/local/bin",
            "/usr/sbin",
            "/usr/bin",
            "/sbin",
            "/bin",
        };

        var buf: [256]u8 = undefined;
        for (candidates) |dir| {
            const full = std.fmt.bufPrint(&buf, "{s}/{s}", .{ dir, name }) catch continue;
            if (std.fs.accessAbsolute(full, .{})) |_| {
                return full;
            } else |_| {}
        }

        return name;
    }

    pub fn ensureFirewall(self: HostProvisioner, vpn_iface: []const u8) !void {
        _ = self;
        const ipt = findTool("iptables");
        const ufw = findTool("ufw");

        const ufw_rules = [_][]const []const u8{
            &[_][]const u8{ ufw, "allow", "22/tcp" },
            &[_][]const u8{ ufw, "allow", "80/tcp" },
            &[_][]const u8{ ufw, "allow", "443/tcp" },
            &[_][]const u8{ ufw, "allow", "443/udp" },
            &[_][]const u8{ ufw, "allow", "in", "on", vpn_iface },
            &[_][]const u8{ ufw, "--force", "enable" },
        };

        var ufw_worked = false;
        for (ufw_rules) |rule| {
            var child = std.process.Child.init(rule, std.heap.page_allocator);
            if (child.spawnAndWait()) |_| {
                ufw_worked = true;
            } else |_| {}
        }

        const nat_rules = [_][]const []const u8{
            &[_][]const u8{ ipt, "-t", "nat", "-A", "POSTROUTING", "-s", "10.42.0.0/16", "-j", "MASQUERADE" },
            &[_][]const u8{ ipt, "-A", "FORWARD", "-i", vpn_iface, "-j", "ACCEPT" },
            &[_][]const u8{ ipt, "-A", "FORWARD", "-o", vpn_iface, "-m", "state", "--state", "RELATED,ESTABLISHED", "-j", "ACCEPT" },
            &[_][]const u8{ ipt, "-A", "INPUT", "-p", "tcp", "--dport", "22", "-j", "ACCEPT" },
            &[_][]const u8{ ipt, "-A", "INPUT", "-p", "tcp", "--dport", "80", "-j", "ACCEPT" },
            &[_][]const u8{ ipt, "-A", "INPUT", "-p", "tcp", "--dport", "443", "-j", "ACCEPT" },
            &[_][]const u8{ ipt, "-A", "INPUT", "-p", "udp", "--dport", "443", "-j", "ACCEPT" },
            &[_][]const u8{ ipt, "-A", "INPUT", "-i", vpn_iface, "-j", "ACCEPT" },
        };

        for (nat_rules) |rule| {
            var child = std.process.Child.init(rule, std.heap.page_allocator);
            _ = child.spawnAndWait() catch {};
        }
    }

    pub fn setupClientRoutes(self: HostProvisioner, vpn_iface: []const u8, server_endpoint: []const u8) void {
        _ = self;
        var server_ip_opt: ?u32 = null;
        var host = server_endpoint;
        if (std.mem.indexOfScalar(u8, server_endpoint, ':')) |colon| {
            host = server_endpoint[0..colon];
        }

        if (std.net.Address.parseIp4(host, 0)) |addr| {
            const octets = std.mem.asBytes(&addr.in.sa.addr);
            server_ip_opt = std.mem.readInt(u32, octets[0..4], .big);
        } else |_| {}

        netlink.Netlink.setupClientRoutes(vpn_iface, server_ip_opt);

        const ip_cmd = findTool("ip");
        var r1 = std.process.Child.init(&[_][]const u8{ ip_cmd, "route", "add", "0.0.0.0/1", "dev", vpn_iface }, std.heap.page_allocator);
        _ = r1.spawnAndWait() catch {};

        var r2 = std.process.Child.init(&[_][]const u8{ ip_cmd, "route", "add", "128.0.0.0/1", "dev", vpn_iface }, std.heap.page_allocator);
        _ = r2.spawnAndWait() catch {};
    }

    pub fn teardownClientRoutes(self: HostProvisioner, vpn_iface: []const u8) void {
        _ = self;
        netlink.Netlink.teardownClientRoutes(vpn_iface, null);

        const ip_cmd = findTool("ip");
        var r1 = std.process.Child.init(&[_][]const u8{ ip_cmd, "route", "del", "0.0.0.0/1", "dev", vpn_iface }, std.heap.page_allocator);
        _ = r1.spawnAndWait() catch {};

        var r2 = std.process.Child.init(&[_][]const u8{ ip_cmd, "route", "del", "128.0.0.0/1", "dev", vpn_iface }, std.heap.page_allocator);
        _ = r2.spawnAndWait() catch {};
    }

    pub fn ensureSshd(self: HostProvisioner) !void {
        _ = self;
        std.fs.cwd().makePath("/etc/ssh/sshd_config.d") catch {};
        const conf =
            \\PasswordAuthentication no
            \\PermitRootLogin prohibit-password
            \\
        ;
        writeFileSafe("/etc/ssh/sshd_config.d/99-unsafie-cloud.conf", conf);
    }

    pub fn ensureService(self: HostProvisioner) !void {
        _ = self;
        var is_systemd = false;
        if (std.fs.openFileAbsolute("/proc/1/comm", .{})) |f| {
            defer f.close();
            var buf: [64]u8 = undefined;
            const len = f.readAll(&buf) catch 0;
            if (std.mem.startsWith(u8, buf[0..len], "systemd")) {
                is_systemd = true;
            }
        } else |_| {}

        if (is_systemd or (std.fs.cwd().access("/run/systemd/system", .{}) catch null) != null) {
            const unit =
                \\[Unit]
                \\Description=Unsafie Cloud Sovereign IaaS & VPN Kernel
                \\After=network.target
                \\
                \\[Service]
                \\Type=notify
                \\ExecStart=/usr/local/bin/unsafie-cloud run
                \\Restart=always
                \\RestartSec=5s
                \\LimitNOFILE=1048576
                \\
                \\[Install]
                \\WantedBy=multi-user.target
                \\
            ;

            writeFileSafe("/etc/systemd/system/unsafie-cloud.service", unit);
            var child = std.process.Child.init(&[_][]const u8{ "systemctl", "daemon-reload" }, std.heap.page_allocator);
            _ = child.spawnAndWait() catch {};
        }
    }

    pub fn bootstrapAll(self: HostProvisioner, vpn_iface: []const u8) !void {
        try self.ensureSysctl();
        try self.ensurePackages();
        try self.ensureFirewall(vpn_iface);
        try self.ensureSshd();
        try self.ensureService();
    }
};
