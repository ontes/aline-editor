const std = @import("std");

pub fn linkDependencies(step: *std.build.LibExeObjStep) void {
    step.linkLibC();
    switch (step.target.os_tag orelse @import("builtin").target.os.tag) {
        .windows => {
            step.linkLibCpp();
            step.linkSystemLibrary("comctl32");
        },
        .linux => {
            step.linkSystemLibrary("gtk-3");
            step.linkSystemLibrary("gdk-3");
        },
        .macos => {
            step.linkFramework("AppKit");
        },
        else => unreachable,
    }
}

pub fn link(step: *std.build.LibExeObjStep, comptime path: []const u8) void {
    linkDependencies(step);

    const src_path = path ++ "nativefiledialogs/src/";

    step.addIncludePath(src_path ++ "include");
    step.addCSourceFile(src_path ++ "nfd_common.c", &.{});

    switch (step.target.os_tag orelse @import("builtin").target.os.tag) {
        .windows => {
            step.addCSourceFile(src_path ++ "nfd_win.cpp", &.{});
        },
        .linux => {
            step.addIncludePath("/usr/include/gtk-3.0");
            step.addIncludePath("/usr/include/glib-2.0");
            step.addIncludePath("/usr/lib/glib-2.0/include");
            step.addIncludePath("/usr/include/pango-1.0");
            step.addIncludePath("/usr/include/harfbuzz");
            step.addIncludePath("/usr/include/cairo");
            step.addIncludePath("/usr/include/gdk-pixbuf-2.0");
            step.addIncludePath("/usr/include/atk-1.0");
            step.addCSourceFile(src_path ++ "nfd_gtk.c", &.{});
        },
        .macos => {
            step.addCSourceFile(src_path ++ "nfd_cocoa.m", &.{});
        },
        else => unreachable,
    }
}

pub fn build(b: *std.build.Builder) void {
    const target = b.standardTargetOptions(.{});
    const build_mode = b.standardReleaseOptions();

    const static_lib = b.addStaticLibrary("nfd", null);
    static_lib.setTarget(target);
    static_lib.setBuildMode(build_mode);
    link(static_lib, "");
    static_lib.install();
}
