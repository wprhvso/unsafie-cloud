const std = @import("std");

pub const HostProvisioner = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) HostProvisioner {
        return .{ .allocator = allocator };
    }

    fn writeProc(path: []const u8, val: []const u8) void {
        if (std.fs.openFileAbsolute(path, .{ .mode = .write_only })) |f| {
            defer f.close();
            f.writeAll(val) catch {};
        } else |_| {}
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
        const path = "/etc/sysctl.d/99-unsafie-cloud.conf";
        if (std.fs.createFileAbsolute(path, .{})) |file| {
            defer file.close();
            file.writeAll(config_data) catch {};
            var child = std.process.Child.init(&[_][]const u8{ "sysctl", "-p", path }, std.heap.page_allocator);
            _ = child.spawnAndWait() catch {};
        } else |_| {}
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

    pub fn ensureFirewall(self: HostProvisioner, vpn_iface: []const u8) !void {
        _ = self;
        const ufw_rules = [_][]const []const u8{
            &[_][]const u8{ "ufw", "allow", "22/tcp" },
            &[_][]const u8{ "ufw", "allow", "80/tcp" },
            &[_][]const u8{ "ufw", "allow", "443/tcp" },
            &[_][]const u8{ "ufw", "allow", "443/udp" },
            &[_][]const u8{ "ufw", "allow", "in", "on", vpn_iface },
            &[_][]const u8{ "ufw", "--force", "enable" },
        };

        var ufw_worked = false;
        for (ufw_rules) |rule| {
            var child = std.process.Child.init(rule, std.heap.page_allocator);
            if (child.spawnAndWait()) |_| {
                ufw_worked = true;
            } else |_| {}
        }

        const nat_rules = [_][]const []const u8{
            &[_][]const u8{ "iptables", "-t", "nat", "-A", "POSTROUTING", "-s", "10.42.0.0/16", "-j", "MASQUERADE" },
            &[_][]const u8{ "iptables", "-A", "FORWARD", "-i", vpn_iface, "-j", "ACCEPT" },
            &[_][]const u8{ "iptables", "-A", "FORWARD", "-o", vpn_iface, "-m", "state", "--state", "RELATED,ESTABLISHED", "-j", "ACCEPT" },
        };

        for (nat_rules) |rule| {
            var child = std.process.Child.init(rule, std.heap.page_allocator);
            _ = child.spawnAndWait() catch {};
        }

        if (!ufw_worked) {
            const ipt_rules = [_][]const []const u8{
                &[_][]const u8{ "iptables", "-A", "INPUT", "-p", "tcp", "--dport", "22", "-j", "ACCEPT" },
                &[_][]const u8{ "iptables", "-A", "INPUT", "-p", "tcp", "--dport", "80", "-j", "ACCEPT" },
                &[_][]const u8{ "iptables", "-A", "INPUT", "-p", "tcp", "--dport", "443", "-j", "ACCEPT" },
                &[_][]const u8{ "iptables", "-A", "INPUT", "-p", "udp", "--dport", "443", "-j", "ACCEPT" },
                &[_][]const u8{ "iptables", "-A", "INPUT", "-i", vpn_iface, "-j", "ACCEPT" },
            };
            for (ipt_rules) |rule| {
                var child = std.process.Child.init(rule, std.heap.page_allocator);
                _ = child.spawnAndWait() catch {};
            }
        }
    }

    pub fn setupClientRoutes(self: HostProvisioner, vpn_iface: []const u8, server_ip: []const u8) void {
        _ = self;
        var r1 = std.process.Child.init(&[_][]const u8{ "ip", "route", "add", "0.0.0.0/1", "dev", vpn_iface }, std.heap.page_allocator);
        _ = r1.spawnAndWait() catch {};

        var r2 = std.process.Child.init(&[_][]const u8{ "ip", "route", "add", "128.0.0.0/1", "dev", vpn_iface }, std.heap.page_allocator);
        _ = r2.spawnAndWait() catch {};

        _ = server_ip;
    }

    pub fn teardownClientRoutes(self: HostProvisioner, vpn_iface: []const u8) void {
        _ = self;
        var r1 = std.process.Child.init(&[_][]const u8{ "ip", "route", "del", "0.0.0.0/1", "dev", vpn_iface }, std.heap.page_allocator);
        _ = r1.spawnAndWait() catch {};

        var r2 = std.process.Child.init(&[_][]const u8{ "ip", "route", "del", "128.0.0.0/1", "dev", vpn_iface }, std.heap.page_allocator);
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
        if (std.fs.createFileAbsolute("/etc/ssh/sshd_config.d/99-unsafie-cloud.conf", .{})) |file| {
            defer file.close();
            file.writeAll(conf) catch {};
        } else |_| {}
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

        if (is_systemd or std.fs.cwd().access("/run/systemd/system", .{}) == .{}) {
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

            if (std.fs.createFileAbsolute("/etc/systemd/system/unsafie-cloud.service", .{})) |file| {
                defer file.close();
                file.writeAll(unit) catch {};
                var child = std.process.Child.init(&[_][]const u8{ "systemctl", "daemon-reload" }, std.heap.page_allocator);
                _ = child.spawnAndWait() catch {};
            } else |_| {}
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
