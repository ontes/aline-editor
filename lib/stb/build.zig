const std = @import("std");

pub fn linkDependencies(step: *std.build.LibExeObjStep) void {
    step.linkLibC();
}

pub fn link(step: *std.build.LibExeObjStep, comptime path: []const u8) void {
    linkDependencies(step);

    step.addIncludePath(path ++ "stb");
    step.addCSourceFile(path ++ "stb_image.c", &.{});
    step.addCSourceFile(path ++ "stb_image_write.c", &.{});
}

pub fn build(b: *std.build.Builder) void {
    const target = b.standardTargetOptions(.{});
    const build_mode = b.standardReleaseOptions();

    const static_lib = b.addStaticLibrary("stb", null);
    static_lib.setTarget(target);
    static_lib.setBuildMode(build_mode);
    link(static_lib, "");
    static_lib.install();
}
