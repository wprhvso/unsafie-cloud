const std = @import("std");
const config = @import("config.zig");
const client = @import("client.zig");

const cmd_auth = @import("commands/auth.zig");
const cmd_vm = @import("commands/vm.zig");
const cmd_iso = @import("commands/iso.zig");
const cmd_image = @import("commands/image.zig");
const cmd_domain = @import("commands/domain.zig");
const cmd_port = @import("commands/port.zig");
const cmd_node = @import("commands/node.zig");
const cmd_token = @import("commands/token.zig");
const cmd_quota = @import("commands/quota.zig");
const cmd_kernel = @import("commands/kernel.zig");
const cmd_top = @import("commands/top.zig");
const cmd_completion = @import("commands/completion.zig");
const cmd_logs = @import("commands/logs.zig");
const cmd_events = @import("commands/events.zig");
const cmd_host = @import("commands/host.zig");
const cmd_service = @import("commands/service.zig");

pub fn printHelp() void {
    std.debug.print(
        \\Unsafie Cloud CLI
        \\Usage: unsafie-cloud <command> [subcommand] [flags]
        \\
        \\Commands:
        \\  run          Run sovereign node daemon and 443 listener
        \\  connect      Connect client to sovereign VPN endpoint (--token <tok>)
        \\  auth         Authentication management (login, status, logout)
        \\  service      Cross-platform service management (install, start, stop, status)
        \\  host         Idempotent host provisioning and sysctl/firewall setup
        \\  node         Cluster nodes and mesh bootstrap (add, list, status)
        \\  token        API token minting and revocation (create, list, revoke)
        \\  vm           Virtual machine lifecycle (ensure, list, get, delete, bake)
        \\  iso          ISO image management (ensure, list, delete)
        \\  image        Custom baked QCOW2 image catalog (list, delete)
        \\  domain       Custom domain mapping and manual PEM SSL
        \\  port         L4 TCP/UDP port forwarding
        \\  quota        User resource quotas and whitelist grants
        \\  kernel       Zero-downtime A/B kernel rollout
        \\  events       Immutable event ledger stream
        \\  logs         Cluster-wide JSONL structured logs
        \\  top          Interactive live terminal TUI dashboard
        \\  completion   Shell completions generator (bash, zsh, fish)
        \\
    , .{});
}

pub fn execute(allocator: std.mem.Allocator, cmd: []const u8, subargs: []const []const u8) !void {
    var cfg = try config.Config.load(allocator);
    defer cfg.deinit(allocator);

    const cl = client.Client.init(allocator, cfg);

    if (std.mem.eql(u8, cmd, "auth")) {
        try cmd_auth.execute(cl, subargs);
    } else if (std.mem.eql(u8, cmd, "vm")) {
        try cmd_vm.execute(cl, subargs);
    } else if (std.mem.eql(u8, cmd, "iso")) {
        try cmd_iso.execute(cl, subargs);
    } else if (std.mem.eql(u8, cmd, "image")) {
        try cmd_image.execute(cl, subargs);
    } else if (std.mem.eql(u8, cmd, "domain")) {
        try cmd_domain.execute(cl, subargs);
    } else if (std.mem.eql(u8, cmd, "port")) {
        try cmd_port.execute(cl, subargs);
    } else if (std.mem.eql(u8, cmd, "node")) {
        try cmd_node.execute(cl, subargs);
    } else if (std.mem.eql(u8, cmd, "token")) {
        try cmd_token.execute(cl, subargs);
    } else if (std.mem.eql(u8, cmd, "quota")) {
        try cmd_quota.execute(cl, subargs);
    } else if (std.mem.eql(u8, cmd, "kernel")) {
        try cmd_kernel.execute(cl, subargs);
    } else if (std.mem.eql(u8, cmd, "host")) {
        try cmd_host.execute(cl, subargs);
    } else if (std.mem.eql(u8, cmd, "service")) {
        try cmd_service.execute(cl, subargs);
    } else if (std.mem.eql(u8, cmd, "events")) {
        try cmd_events.execute(cl, subargs);
    } else if (std.mem.eql(u8, cmd, "logs")) {
        try cmd_logs.execute(cl, subargs);
    } else if (std.mem.eql(u8, cmd, "top")) {
        try cmd_top.execute(cl, subargs);
    } else if (std.mem.eql(u8, cmd, "completion")) {
        try cmd_completion.execute(subargs);
    } else {
        std.debug.print("Unknown command: {s}\nRun unsafie-cloud help for available commands.\n", .{cmd});
    }
}
