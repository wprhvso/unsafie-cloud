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
        } else if (std.mem.eql(u8, action, "node.add") or std.mem.eql(u8, action, "node.ensure")) {
            if (!is_admin) return error.AccessDenied;
            return admin_h.AdminHandler.handleNodeEnsure(allocator, params);
        } else if (std.mem.eql(u8, action, "node.list")) {
            return admin_h.AdminHandler.handleNodeList(allocator);
        } else if (std.mem.eql(u8, action, "node.delete")) {
            if (!is_admin) return error.AccessDenied;
            return admin_h.AdminHandler.handleNodeDelete(allocator, params);
        } else if (std.mem.eql(u8, action, "node.bake")) {
            if (!is_admin) return error.AccessDenied;
            return admin_h.AdminHandler.handleNodeBake(allocator, params);
        } else if (std.mem.eql(u8, action, "vpn.ensure")) {
            if (!is_admin) return error.AccessDenied;
            return admin_h.AdminHandler.handleVpnEnsure(allocator, params);
        } else if (std.mem.eql(u8, action, "vpn.status")) {
            return admin_h.AdminHandler.handleVpnStatus(allocator);
        } else if (std.mem.eql(u8, action, "route.ensure")) {
            if (!is_admin) return error.AccessDenied;
            return admin_h.AdminHandler.handleRouteEnsure(allocator, params);
        } else if (std.mem.eql(u8, action, "mesh.topology")) {
            return admin_h.AdminHandler.handleMeshTopology(allocator);
        } else if (std.mem.eql(u8, action, "logs.get") or std.mem.eql(u8, action, "logs.tail")) {
            return admin_h.AdminHandler.handleLogsGet(allocator, params);
        } else if (std.mem.eql(u8, action, "logs.search")) {
            return admin_h.AdminHandler.handleLogsSearch(allocator, params);
        } else if (std.mem.eql(u8, action, "events.status") or std.mem.eql(u8, action, "events.list")) {
            return admin_h.AdminHandler.handleEventsStatus(allocator);
        } else if (std.mem.eql(u8, action, "kernel.upgrade")) {
            if (!is_admin) return error.AccessDenied;
            return admin_h.AdminHandler.handleKernelUpgrade(allocator, params);
        }
        return error.UnknownAction;
    }
};
