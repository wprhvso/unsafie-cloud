const std = @import("std");

pub const BakeOptions = struct {
    name: []const u8,
    role: []const u8 = "guest",
    target: []const u8 = "linux-bin",
    server_endpoint: []const u8 = "vpn.unsafie.com:443",
    assigned_ip: []const u8 = "10.42.20.15",
};

pub const BakeService = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) BakeService {
        return .{ .allocator = allocator };
    }

    pub fn bakeArtifact(self: BakeService, options: BakeOptions, out_path: []const u8) !void {
        _ = self;
        var file = try std.fs.cwd().createFile(out_path, .{});
        defer file.close();

        const dummy_elf_header = [_]u8{ 0x7f, 'E', 'L', 'F', 2, 1, 1, 0 } ++ [_]u8{0} ** 56;
        try file.writeAll(&dummy_elf_header);

        var buf: [512]u8 = undefined;
        const config_str = try std.fmt.bufPrint(&buf, "{{\"name\":\"{s}\",\"role\":\"{s}\",\"target\":\"{s}\",\"server\":\"{s}\",\"ip\":\"{s}\"}}", .{
            options.name,
            options.role,
            options.target,
            options.server_endpoint,
            options.assigned_ip,
        });

        try file.writeAll(config_str);

        const magic = "UNSAFIE_OVERLAY_MAGIC";
        try file.writeAll(magic);

        var len_buf: [4]u8 = undefined;
        std.mem.writeInt(u32, &len_buf, @intCast(config_str.len), .little);
        try file.writeAll(&len_buf);
    }
};
