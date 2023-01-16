const std = @import("std");
const platform = @import("platform");
const render = @import("render");
const webgpu = @import("webgpu");
const imgui = @import("imgui");
const imgui_impl_wgpu = imgui.impl_wgpu(webgpu);

const editor = @import("editor.zig");

const desired_frame_time = 10 * std.time.ns_per_ms;

var window: platform.Window = undefined;

var context: render.Context = undefined;
var buffers: [3]render.Buffer = undefined;

var should_run = true;
var time: i128 = undefined;

fn init(allocator: std.mem.Allocator) !void {
    try platform.init();
    window = try platform.Window.create(.{ 0, 0 }, .{ 1280, 720 }, "Aline Editor");
    window.show();

    context = try render.Context.init(window);
    for (buffers) |*buffer|
        buffer.* = render.Buffer.init(&context, allocator);

    try editor.init(allocator, context);

    time = std.time.nanoTimestamp();
}

fn deinit() void {
    editor.deinit();

    for (buffers) |*buffer|
        buffer.deinit();
    context.deinit();

    window.destroy();
    platform.deinit();
}

fn onFrame() !void {
    try platform.pollEvents(onEvent);

    if (try editor.redraw(&buffers[0], &buffers[1], &buffers[2]))
        context.draw(draw);

    const frame_time = std.time.nanoTimestamp() - time;
    if (frame_time < desired_frame_time)
        std.time.sleep(@intCast(u64, desired_frame_time - frame_time));
    time = std.time.nanoTimestamp();
}

fn draw(pass: *webgpu.RenderPassEncoder) void {
    for (buffers) |buffer| {
        buffer.draw(pass);
    }
    imgui_impl_wgpu.renderDrawData(imgui.getDrawData().?, pass);
}

fn onEvent(event: platform.Event, _: platform.Window) !void {
    switch (event) {
        .window_close => should_run = false,
        .window_resize => |size| context.onWindowResize(size),
        else => {},
    }
    try editor.onEvent(event);
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    try init(gpa.allocator());
    defer deinit();

    while (should_run) {
        try onFrame();
    }
}
