const std = @import("std");

// TODO: add ability to use ox-smd from build.zig?

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const @"ox-smd" = b.addModule("ox-smd", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const unit_tests = b.addTest(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    unit_tests.filters = if (b.option([]const u8, "test-filter", "test filter")) |filter|
        try b.allocator.dupe([]const u8, &.{filter})
    else
        &.{};

    const run_unit_tests = b.addRunArtifact(unit_tests);
    if (b.args) |args| run_unit_tests.addArgs(args);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);

    const @"ox-smd_exe" = b.addExecutable(.{
        .name = "ox-smd",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    @"ox-smd_exe".root_module.addImport("or-smd", @"ox-smd");

    const run_exe = b.addRunArtifact(@"ox-smd_exe");
    if (b.args) |args| run_exe.addArgs(args);
    const run_exe_step = b.step("run", "Run the ox-smd tool");
    run_exe_step.dependOn(&run_exe.step);

    b.installArtifact(@"ox-smd_exe");

    const check = b.addExecutable(.{
        .name = "ox-smd_check",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    check.root_module.addImport("ox-smd", @"ox-smd");
    const check_step = b.step("check", "Check if ox-smd compiles");
    check_step.dependOn(&check.step);

    const release_step = b.step("release", "Create releases for the ox-smd CLI tool");
    const targets: []const std.Target.Query = &.{
        .{ .cpu_arch = .aarch64, .os_tag = .macos },
        .{ .cpu_arch = .aarch64, .os_tag = .linux },
        .{ .cpu_arch = .aarch64, .os_tag = .windows },
        .{ .cpu_arch = .x86_64, .os_tag = .macos },
        .{ .cpu_arch = .x86_64, .os_tag = .linux, .abi = .musl },
        .{ .cpu_arch = .x86_64, .os_tag = .windows },
    };

    for (targets) |t| {
        const release_target = b.resolveTargetQuery(t);
        const release_exe = b.addExecutable(.{
            .name = "ox-smd",
            .root_source_file = b.path("src/main.zig"),
            .target = release_target,
            .optimize = .ReleaseFast,
        });
        release_exe.root_module.addImport("ox-smd", @"ox-smd");

        const target_output = b.addInstallArtifact(release_exe, .{
            .dest_dir = .{ .override = .{ .custom = try t.zigTriple(b.allocator) } },
        });
        release_step.dependOn(&target_output.step);
    }
}
