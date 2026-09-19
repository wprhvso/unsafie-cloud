const std = @import("std");

pub const ProtocolType = enum {
    http3,
    http2,
    http1_1,
    http1_0,
    websocket,
};
