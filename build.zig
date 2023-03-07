const std = @import("std");
const imgui_build = @import("lib/imgui/build.zig");
const dawn_build = @import("lib/dawn/build.zig");
const nativefiledialogs_build = @import("lib/nativefiledialogs/build.zig");
const stb_build = @import("lib/stb/build.zig");

const webgpu_pkg = std.build.Pkg{
    .name = "webgpu",
    .source = .{ .path = "lib/dawn/webgpu.zig" },
};
const platform_pkg = std.build.Pkg{
    .name = "platform",
    .source = .{ .path = "src/platform/platform.zig" },
};
const math_pkg = std.build.Pkg{
    .name = "math",
    .source = .{ .path = "src/math/math.zig" },
};
const render_pkg = std.build.Pkg{
    .name = "render",
    .source = .{ .path = "src/render/render.zig" },
    .dependencies = &.{ webgpu_pkg, platform_pkg, math_pkg },
};
const imgui_pkg = std.build.Pkg{
    .name = "imgui",
    .source = .{ .path = "lib/imgui/imgui.zig" },
};
const imgui_impl_wgpu_pkg = std.build.Pkg{
    .name = "imgui_impl_wgpu",
    .source = .{ .path = "lib/imgui/imgui_impl_wgpu.zig" },
    .dependencies = &.{ imgui_pkg, webgpu_pkg },
};
const nfd_pkg = std.build.Pkg{
    .name = "nfd",
    .source = .{ .path = "lib/nativefiledialogs/nfd.zig" },
};
const stb_pkg = std.build.Pkg{
    .name = "stb",
    .source = .{ .path = "lib/stb/stb.zig" },
};

pub fn build(b: *std.build.Builder) !void {
    const target = b.standardTargetOptions(.{});
    const mode = b.standardReleaseOptions();
    const os_tag = target.os_tag orelse @import("builtin").target.os.tag;

    const exe = b.addExecutable("aline-editor", "src/editor/main.zig");
    exe.setTarget(target);
    exe.setBuildMode(mode);

    // dawn
    if (std.fs.cwd().access("lib/dawn/zig-out", .{})) |_| { // don't build dawn when dawn binary is available
        std.debug.print("Using webgpu_dawn library from 'lib/dawn/zig-out/lib'\n", .{});
        exe.addLibraryPath("lib/dawn/zig-out/lib");
        exe.linkSystemLibrary("webgpu_dawn");
        exe.addIncludePath("lib/dawn/dawn/include");
        exe.addIncludePath("lib/dawn/dawn-gen/include");
    } else |_| {
        dawn_build.link(exe, .{
            .enable_d3d12 = false,
            .enable_metal = false,
            .enable_null = true,
            .enable_opengl = os_tag == .linux,
            .enable_opengles = os_tag == .linux,
            .enable_vulkan = true,
            .use_wayland = false,
            .use_x11 = os_tag == .linux,
        }, "lib/dawn/");
    }
    exe.addPackage(webgpu_pkg);

    // imgui
    imgui_build.link(exe, "lib/imgui/");
    imgui_build.linkImpl(exe, "wgpu", "lib/imgui/");
    exe.addPackage(imgui_pkg);
    exe.addPackage(imgui_impl_wgpu_pkg);

    // nativefiledialogs
    const nfd_lib = b.addStaticLibrary("nfd", null);
    nfd_lib.setTarget(target);
    nfd_lib.setBuildMode(mode);
    nativefiledialogs_build.link(nfd_lib, "lib/nativefiledialogs/");
    exe.linkLibrary(nfd_lib);
    exe.addPackage(nfd_pkg);

    const stb_lib = b.addStaticLibrary("stb", null);
    stb_lib.setTarget(target);
    stb_lib.setBuildMode(mode);
    stb_build.link(stb_lib, "lib/stb/");
    exe.linkLibrary(stb_lib);
    exe.addPackage(stb_pkg);

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

    const exe_tests = b.addTest("src/editor/main.zig");
    exe_tests.setTarget(target);
    exe_tests.setBuildMode(mode);
    b.step("test", "Run unit tests").dependOn(&exe_tests.step);
}
