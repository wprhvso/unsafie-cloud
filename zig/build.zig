const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const is_android = target.result.abi.isAndroid();

    const gen_rules_exe = b.addExecutable(.{
        .name = "gen_rules",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/gen_rules.zig"),
            .target = b.graph.host,
            .optimize = .Debug,
        }),
    });
    const gen_rules_cmd = b.addRunArtifact(gen_rules_exe);
    gen_rules_cmd.addArgs(&[_][]const u8{"src/routing/rules.bin"});
    const gen_rules_step = b.step("gen-rules", "Generate rules.bin database");
    gen_rules_step.dependOn(&gen_rules_cmd.step);

    if (!is_android) {
        const exe = b.addExecutable(.{
            .name = "unsafie",
            .root_module = b.createModule(.{
                .root_source_file = b.path("src/main.zig"),
                .target = target,
                .optimize = optimize,
            }),
        });

        b.installArtifact(exe);

        const run_cmd = b.addRunArtifact(exe);
        run_cmd.step.dependOn(b.getInstallStep());
        run_cmd.setCwd(b.path(".."));
        if (b.args) |args| {
            run_cmd.addArgs(args);
        }
        const run_step = b.step("run", "Run unsafie");
        run_step.dependOn(&run_cmd.step);

        const unit_tests = b.addTest(.{
            .root_module = b.createModule(.{
                .root_source_file = b.path("src/main.zig"),
                .target = target,
                .optimize = optimize,
            }),
        });
        const run_unit_tests = b.addRunArtifact(unit_tests);
        const test_step = b.step("test", "Run unit tests");
        test_step.dependOn(&run_unit_tests.step);
    }

    const lib = b.addLibrary(.{
        .linkage = .dynamic,
        .name = "unsafie_core",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/android.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    b.installArtifact(lib);
}
