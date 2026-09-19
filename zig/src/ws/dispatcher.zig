const std = @import("std");
const vm_h = @import("../handlers/vm.zig");
const iso_h = @import("../handlers/iso.zig");
const port_h = @import("../handlers/port.zig");
const domain_h = @import("../handlers/domain.zig");
const token_h = @import("../handlers/token.zig");
const admin_h = @import("../handlers/admin.zig");
const image_h = @import("../handlers/image.zig");

pub const Dispatcher = struct {
    pub fn dispatch(allocator: std.mem.Allocator, action: []const u8, params: ?std.json.Value, is_admin: bool) !std.json.Value {
        if (std.mem.eql(u8, action, "vm.ensure")) {
            return vm_h.VmHandler.handleEnsure(allocator, params);
        } else if (std.mem.eql(u8, action, "vm.get")) {
            return vm_h.VmHandler.handleGet(allocator, params);
        } else if (std.mem.eql(u8, action, "vm.delete")) {
            return vm_h.VmHandler.handleDelete(allocator, params);
        } else if (std.mem.eql(u8, action, "vm.bake")) {
            return vm_h.VmHandler.handleBake(allocator, params);
        } else if (std.mem.eql(u8, action, "iso.ensure")) {
            return iso_h.IsoHandler.handleEnsure(allocator, params);
        } else if (std.mem.eql(u8, action, "iso.list")) {
            return iso_h.IsoHandler.handleList(allocator);
        } else if (std.mem.eql(u8, action, "port.ensure")) {
            return port_h.PortHandler.handleEnsure(allocator, params);
        } else if (std.mem.eql(u8, action, "domain.ensure")) {
            return domain_h.DomainHandler.handleEnsure(allocator, params);
        } else if (std.mem.eql(u8, action, "token.ensure")) {
            if (!is_admin) return error.AccessDenied;
            return token_h.TokenHandler.handleEnsure(allocator, params);
        } else if (std.mem.eql(u8, action, "image.list")) {
            return image_h.ImageHandler.handleList(allocator);
        } else if (std.mem.eql(u8, action, "admin.grant_port")) {
            if (!is_admin) return error.AccessDenied;
            return admin_h.AdminHandler.handleGrantPort(allocator, params);
        }
        return error.UnknownAction;
    }
};
