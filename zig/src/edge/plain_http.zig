const std = @import("std");

pub const PlainHttpHandler = struct {
    pub fn handleRequest(target_path: []const u8) ![]const u8 {
        if (std.mem.eql(u8, target_path, "/healthz")) {
            return "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: 15\r\n\r\n{\"status\":\"ok\"}";
        }
        return "HTTP/1.1 301 Moved Permanently\r\nLocation: https://\r\nContent-Length: 0\r\n\r\n";
    }
};
