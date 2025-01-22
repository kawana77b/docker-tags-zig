const std = @import("std");

pub fn build(b: *std.Build) void {
    // NOTE: https://github.com/ziglang/zig/pull/20271
    // Currently, the version is set from the main file.
    // It will be possible to set the meta value directly in build.zon from 0.14.0 onwards...
    const build_options = b.addOptions();
    build_options.addOption([]const u8, "version", "0.1.1");
    build_options.addOption([]const u8, "app_name", "docker-tags");
    // build_options.addOption([]const u8, "version", @import("build.zig.zon").version);

    const target = b.standardTargetOptions(.{});

    const optimize = b.standardOptimizeOption(.{ .preferred_optimize_mode = .ReleaseSmall });

    const exe = b.addExecutable(.{
        .name = "docker-tags",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addOptions("build_options", build_options);

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const exe_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    // Similar to creating the run step earlier, this exposes a `test` step to
    // the `zig build --help` menu, providing a way for the user to request
    // running the unit tests.
    const test_step = b.step("test", "Run unit tests");
    // test_step.dependOn(&run_lib_unit_tests.step);
    test_step.dependOn(&run_exe_unit_tests.step);

    const copiles = [_]*std.Build.Step.Compile{ exe, exe_unit_tests };
    //-------------------------------------------------------
    // Dependency
    //-------------------------------------------------------
    const lib_chroma = b.dependency("chroma", .{
        .target = target,
        .optimize = optimize,
    });
    for (copiles) |compile| {
        compile.root_module.addImport("chroma", lib_chroma.module("chroma"));
    }

    const lib_clap = b.dependency("clap", .{});
    for (copiles) |compile| {
        compile.root_module.addImport("clap", lib_clap.module("clap"));
    }

    const lib_pretty_tablezig = b.dependency("prettytable", .{});
    for (copiles) |compile| {
        compile.root_module.addImport("prettytable", lib_pretty_tablezig.module("prettytable"));
    }

    const lib_zul = b.dependency("zul", .{});
    for (copiles) |compile| {
        compile.root_module.addImport("zul", lib_zul.module("zul"));
    }
}
