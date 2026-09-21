const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "unsafie-cloud",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const sqlite_dep = b.dependency("sqlite", .{});
    exe.addIncludePath(sqlite_dep.path("."));
    exe.addCSourceFile(.{
        .file = sqlite_dep.path("sqlite3.c"),
        .flags = &[_][]const u8{
            "-DSQLITE_ENABLE_FTS5",
            "-DSQLITE_ENABLE_RTREE",
            "-DSQLITE_THREADSAFE=1",
            "-DSQLITE_ENABLE_JSON1",
            "-DSQLITE_OMIT_LOAD_EXTENSION",
        },
    });
    exe.linkLibC();
    b.installArtifact(exe);

    const lib = b.addLibrary(.{
        .linkage = .dynamic,
        .name = "unsafie_core",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/vpn/platform/android.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    b.installArtifact(lib);
}
