const std = @import("std");

pub const HostProvisioner = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) HostProvisioner {
        return .{ .allocator = allocator };
    }

    pub fn ensureSysctl(self: HostProvisioner) !void {
        _ = self;
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
            \\
        ;

        const path = "/etc/sysctl.d/99-unsafie.conf";
        const file = std.fs.createFileAbsolute(path, .{}) catch return;
        defer file.close();
        file.writeAll(config_data) catch {};

        var child = std.process.Child.init(&[_][]const u8{ "sysctl", "-p", path }, std.heap.page_allocator);
        _ = child.spawnAndWait() catch {};
    }

    pub fn ensurePackages(self: HostProvisioner) !void {
        _ = self;
        var child = std.process.Child.init(&[_][]const u8{
            "apt-get", "install",     "-y",    "--no-install-recommends",
            "curl",    "htop",        "git",   "jq",
            "tmux",    "tar",         "unzip", "ca-certificates",
            "gnupg",   "lsb-release", "rsync", "ufw",
        }, std.heap.page_allocator);
        _ = child.spawnAndWait() catch {};
    }

    pub fn ensureFirewall(self: HostProvisioner, vpn_iface: []const u8) !void {
        _ = self;
        const rules = [_][]const []const u8{
            &[_][]const u8{ "ufw", "allow", "22/tcp" },
            &[_][]const u8{ "ufw", "allow", "80/tcp" },
            &[_][]const u8{ "ufw", "allow", "443/tcp" },
            &[_][]const u8{ "ufw", "allow", "443/udp" },
            &[_][]const u8{ "ufw", "allow", "in", "on", vpn_iface },
            &[_][]const u8{ "ufw", "--force", "enable" },
        };

        for (rules) |rule| {
            var child = std.process.Child.init(rule, std.heap.page_allocator);
            _ = child.spawnAndWait() catch {};
        }
    }

    pub fn ensureSshd(self: HostProvisioner) !void {
        _ = self;
        std.fs.cwd().makePath("/etc/ssh/sshd_config.d") catch {};
        const conf =
            \\PasswordAuthentication no
            \\PermitRootLogin prohibit-password
            \\
        ;
        const file = std.fs.createFileAbsolute("/etc/ssh/sshd_config.d/99-unsafie.conf", .{}) catch return;
        defer file.close();
        file.writeAll(conf) catch {};
    }

    pub fn ensureSystemdUnit(self: HostProvisioner) !void {
        _ = self;
        const unit =
            \\[Unit]
            \\Description=Unsafie Cloud Sovereign IaaS & VPN Kernel
            \\After=network.target
            \\
            \\[Service]
            \\Type=notify
            \\ExecStart=/usr/local/bin/unsafie-cloud
            \\Restart=always
            \\RestartSec=5s
            \\LimitNOFILE=1048576
            \\
            \\[Install]
            \\WantedBy=multi-user.target
            \\
        ;

        const file = std.fs.createFileAbsolute("/etc/systemd/system/unsafie-cloud.service", .{}) catch return;
        defer file.close();
        file.writeAll(unit) catch {};

        var child = std.process.Child.init(&[_][]const u8{ "systemctl", "daemon-reload" }, std.heap.page_allocator);
        _ = child.spawnAndWait() catch {};
    }

    pub fn bootstrapAll(self: HostProvisioner, vpn_iface: []const u8) !void {
        try self.ensureSysctl();
        try self.ensurePackages();
        try self.ensureFirewall(vpn_iface);
        try self.ensureSshd();
        try self.ensureSystemdUnit();
    }
};
