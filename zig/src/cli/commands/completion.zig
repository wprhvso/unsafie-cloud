const std = @import("std");

pub fn execute(args: []const []const u8) !void {
    if (args.len < 1) {
        std.debug.print("Usage: unsafie completion <bash|zsh|fish>\n", .{});
        return;
    }
    const shell = args[0];
    if (std.mem.eql(u8, shell, "bash")) {
        std.debug.print("complete -W 'auth vm iso image domain port node token quota kernel top' unsafie\n", .{});
    } else if (std.mem.eql(u8, shell, "zsh")) {
        std.debug.print("#compdef unsafie\n_arguments '1: :((auth vm iso image domain port node token quota kernel top))'\n", .{});
    } else if (std.mem.eql(u8, shell, "fish")) {
        std.debug.print("complete -c unsafie -f -a 'auth vm iso image domain port node token quota kernel top'\n", .{});
    }
}
