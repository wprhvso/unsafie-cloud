const std = @import("std");

pub fn build(builder: *std.Build) void {
    const target = builder.standardTargetOptions(.{});
    const optimize = builder.standardOptimizeOption(.{});

    const is_android = target.result.abi.isAndroid();

    if (!is_android) {
        const exe = builder.addExecutable(.{
            .name = "unsafie-cloud",
            .root_module = builder.createModule(.{
                .root_source_file = builder.path("src/main.zig"),
                .target = target,
                .optimize = optimize,
            }),
        });

        const sqlite_dep = builder.dependency("sqlite", .{});
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
        builder.installArtifact(exe);
    }

    const lib = builder.addLibrary(.{
        .linkage = .dynamic,
        .name = "unsafie_core",
        .root_module = builder.createModule(.{
            .root_source_file = builder.path("src/vpn/platform/android.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    builder.installArtifact(lib);

    if (!is_android) {
        const sqlite_dep = builder.dependency("sqlite", .{});
        const test_step = builder.step("test", "Run tests");
        const unit_tests = builder.addTest(.{
            .root_module = builder.createModule(.{
                .root_source_file = builder.path("src/main.zig"),
                .target = target,
                .optimize = optimize,
            }),
        });
        unit_tests.addIncludePath(sqlite_dep.path("."));
        unit_tests.addCSourceFile(.{
            .file = sqlite_dep.path("sqlite3.c"),
            .flags = &[_][]const u8{
                "-DSQLITE_ENABLE_FTS5",
                "-DSQLITE_ENABLE_RTREE",
                "-DSQLITE_THREADSAFE=1",
                "-DSQLITE_ENABLE_JSON1",
                "-DSQLITE_OMIT_LOAD_EXTENSION",
            },
        });
        unit_tests.linkLibC();
        const run_unit_tests = builder.addRunArtifact(unit_tests);
        test_step.dependOn(&run_unit_tests.step);
    }
}
