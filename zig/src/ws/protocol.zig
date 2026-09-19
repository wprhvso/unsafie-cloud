const std = @import("std");

pub const FrameType = enum {
    request,
    response,
    event,
};

pub const ProtocolError = error{
    InvalidJson,
    MissingAction,
    Unauthorized,
    UnknownAction,
};
