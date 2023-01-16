const std = @import("std");
const imgui_build = @import("imgui-zig/build.zig");
const dawn_build = @import("dawn-zig/build.zig");

const imgui_pkg = std.build.Pkg{
    .name = "imgui",
    .source = .{ .path = "imgui-zig/imgui.zig" },
};
const webgpu_pkg = std.build.Pkg{
    .name = "webgpu",
    .source = .{ .path = "dawn-zig/webgpu.zig" },
};
const platform_pkg = std.build.Pkg{
    .name = "platform",
    .source = .{ .path = "platform/platform.zig" },
    .dependencies = &.{imgui_pkg},
};
const math_pkg = std.build.Pkg{
    .name = "math",
    .source = .{ .path = "math/math.zig" },
};
const render_pkg = std.build.Pkg{
    .name = "render",
    .source = .{ .path = "render/render.zig" },
    .dependencies = &.{ webgpu_pkg, platform_pkg, math_pkg },
};

pub fn build(b: *std.build.Builder) !void {
    const target = b.standardTargetOptions(.{});
    const mode = b.standardReleaseOptions();
    const os_tag = target.os_tag orelse @import("builtin").target.os.tag;

    const exe = b.addExecutable("aline-editor", "editor/main.zig");
    exe.setTarget(target);
    exe.setBuildMode(mode);

    // imgui-zig
    imgui_build.link(exe, "imgui-zig/");
    imgui_build.linkImpl(exe, "wgpu", "imgui-zig/");
    exe.addPackage(imgui_pkg);

    // dawn-zig
    if (false) { // TODO: check if webgpu_dawn build exists
        exe.addLibraryPath(".");
        exe.linkSystemLibrary("webgpu_dawn");
    } else {
        dawn_build.link(exe, .{
            .enable_d3d12 = false,
            .enable_metal = false,
            .enable_null = true,
            .enable_opengl = os_tag == .linux,
            .enable_opengles = os_tag == .linux,
            .enable_vulkan = true,
            .use_wayland = false,
            .use_x11 = os_tag == .linux,
        }, "dawn-zig/");
    }
    exe.addPackage(webgpu_pkg);

    // platform
    switch (target.os_tag orelse @import("builtin").target.os.tag) {
        .linux => exe.linkSystemLibrary("X11"),
        .windows => exe.linkSystemLibrary("user32"),
        else => return error.UnsupportedTarget,
    }
    exe.addPackage(platform_pkg);

    // math, render
    exe.addPackage(math_pkg);
    exe.addPackage(render_pkg);

    exe.install();

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const exe_tests = b.addTest("editor/main.zig");
    exe_tests.setTarget(target);
    exe_tests.setBuildMode(mode);
    b.step("test", "Run unit tests").dependOn(&exe_tests.step);
}
