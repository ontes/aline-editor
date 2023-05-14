const std = @import("std");
const imgui_build = @import("lib/imgui/build.zig");
const dawn_build = @import("lib/dawn/build.zig");
const nativefiledialogs_build = @import("lib/nativefiledialog/build.zig");
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
    .source = .{ .path = "lib/nativefiledialog/nfd.zig" },
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
    const dawn_lib = b.addStaticLibrary("dawn", null);
    dawn_lib.setTarget(target);
    dawn_lib.setBuildMode(mode);
    dawn_build.link(dawn_lib, .{
        .enable_d3d12 = false,
        .enable_metal = false,
        .enable_null = true,
        .enable_opengl = os_tag == .linux,
        .enable_opengles = os_tag == .linux,
        .enable_vulkan = true,
        .use_wayland = false,
        .use_x11 = os_tag == .linux,
    }, "lib/dawn/");

    if (std.fs.cwd().access("lib/dawn/zig-out", .{})) |_| { // don't build dawn when dawn binary is available
        std.debug.print("Using webgpu_dawn library from 'lib/dawn/zig-out/lib'\n", .{});
        exe.addLibraryPath("lib/dawn/zig-out/lib");
        exe.linkSystemLibrary("webgpu_dawn");
    } else |_| {
        exe.linkLibrary(dawn_lib);
    }
    exe.addPackage(webgpu_pkg);

    // imgui
    const imgui_lib = b.addStaticLibrary("imgui", null);
    imgui_build.link(imgui_lib, "lib/imgui/");

    imgui_lib.addIncludePath("lib/dawn/dawn/include");
    imgui_lib.addIncludePath("lib/dawn/dawn-gen/include");
    imgui_build.linkImpl(imgui_lib, "wgpu", "lib/imgui/");

    exe.linkLibrary(imgui_lib);
    exe.addPackage(imgui_pkg);
    exe.addPackage(imgui_impl_wgpu_pkg);

    // nativefiledialog
    const nfd_lib = b.addStaticLibrary("nfd", null);
    nfd_lib.setTarget(target);
    nfd_lib.setBuildMode(mode);
    nativefiledialogs_build.link(nfd_lib, "lib/nativefiledialog/");
    exe.linkLibrary(nfd_lib);
    exe.addPackage(nfd_pkg);

    // stb
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
    if (b.args) |args| run_cmd.addArgs(args);
    b.step("run", "Run the app").dependOn(&run_cmd.step);

    // performance test

    const exe_perf = b.addExecutable("aline-editor-perf-test", "src/editor/main_perf_test.zig");
    exe_perf.setTarget(target);
    exe_perf.setBuildMode(mode);

    if (std.fs.cwd().access("lib/dawn/zig-out", .{})) |_| { // don't build dawn when dawn binary is available
        std.debug.print("Using webgpu_dawn library from 'lib/dawn/zig-out/lib'\n", .{});
        exe_perf.addLibraryPath("lib/dawn/zig-out/lib");
        exe_perf.linkSystemLibrary("webgpu_dawn");
        exe_perf.addIncludePath("lib/dawn/dawn/include");
        exe_perf.addIncludePath("lib/dawn/dawn-gen/include");
    } else |_| {
        exe_perf.linkLibrary(dawn_lib);
    }
    exe_perf.addPackage(webgpu_pkg);

    exe_perf.linkLibrary(imgui_lib);
    exe_perf.addPackage(imgui_pkg);
    exe_perf.addPackage(imgui_impl_wgpu_pkg);

    exe_perf.linkLibrary(nfd_lib);
    exe_perf.addPackage(nfd_pkg);

    exe_perf.linkLibrary(stb_lib);
    exe_perf.addPackage(stb_pkg);

    switch (target.os_tag orelse @import("builtin").target.os.tag) {
        .linux => exe_perf.linkSystemLibrary("X11"),
        .windows => exe_perf.linkSystemLibrary("user32"),
        else => return error.UnsupportedTarget,
    }
    exe_perf.addPackage(platform_pkg);

    exe_perf.addPackage(math_pkg);
    exe_perf.addPackage(render_pkg);

    const run_cmd_perf = exe_perf.run();
    // run_cmd_perf.step.dependOn(&b.addInstallArtifact(exe_perf).step);
    if (b.args) |args| run_cmd_perf.addArgs(args);
    b.step("perf", "Run performance test").dependOn(&run_cmd_perf.step);
}
