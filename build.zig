const std = @import("std");

pub fn build(b: *std.Build) void {
    // Debug, ReleaseSafe, ReleaseFast, ReleaseSmall
    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});

    const app = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    const app_compile = b.addExecutable(.{
        .name = "py_lsp",
        .root_module = app,
    });
    b.installArtifact(app_compile);

    const run_cmd = b.addRunArtifact(app_compile);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);


    const unit_test= b.addTest(.{
        .root_source_file = b.path("src/unit_test.zig")
    });
    const unit_test_run= b.addRunArtifact(unit_test);
    const unit_test_step = b.step("test:unit", "Run unit tests");
    unit_test_step.dependOn(&unit_test_run.step);
}
