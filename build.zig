const std = @import("std");

pub fn build(b: *std.Build) void {
    const srec = b.addModule("srec", .{
        .source_file = .{ .path = "srec.zig" },
    });

    const tests = b.addTest(.{
        .root_source_file = .{ .path = "tests.zig"},
        .target = b.standardTargetOptions(.{}),
        .optimize = b.standardOptimizeOption(.{}),
    });
    tests.addModule("srec", srec);
    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run all tests");
    test_step.dependOn(&run_tests.step);
}
