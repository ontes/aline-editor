const std = @import("std");
const platform = @import("platform");
const render = @import("render");
const webgpu = @import("webgpu");
const imgui = @import("imgui");
const imgui_impl_wgpu = @import("imgui_impl_wgpu");

const editor = @import("editor.zig");
const canvas = @import("canvas.zig");
const input = @import("input.zig");
const input_basic = @import("input_basic.zig");
const input_gui = @import("input_gui.zig");

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

    try editor.init(allocator);
    input_gui.init(context);

    time = std.time.nanoTimestamp();
}

fn deinit() void {
    editor.deinit();
    input_gui.deinit();

    for (buffers) |*buffer|
        buffer.deinit();
    context.deinit();

    window.destroy();
    platform.deinit();
}

fn onFrame() !void {
    try platform.pollEvents(onEvent);

    try input_gui.onFrame();

    var should_render = true; // TODO detect when ImGui want's to render

    if (editor.should_draw_canvas) {
        buffers[0].clear();
        try canvas.draw(&buffers[0]);
        buffers[0].flush();
        editor.should_draw_canvas = false;
        should_render = true;
    }
    if (editor.should_draw_image) {
        buffers[1].clear();
        try editor.drawImage(&buffers[1]);
        buffers[1].flush();
        editor.should_draw_image = false;
        should_render = true;
    }
    if (editor.should_draw_helper) {
        buffers[2].clear();
        try editor.drawHelper(&buffers[2]);
        buffers[2].flush();
        editor.should_draw_helper = false;
        should_render = true;
    }
    if (editor.should_update_transform) {
        for (buffers) |*buffer|
            buffer.setTransform(canvas.transform());
        editor.should_update_transform = false;
        should_render = true;
    }

    if (should_render)
        context.render(onRender);

    const frame_time = std.time.nanoTimestamp() - time;
    if (frame_time < desired_frame_time)
        std.time.sleep(@intCast(u64, desired_frame_time - frame_time));
    time = std.time.nanoTimestamp();
}

fn onRender(pass: *webgpu.RenderPassEncoder) void {
    for (buffers) |buffer| {
        buffer.render(pass);
    }
    imgui_impl_wgpu.renderDrawData(imgui.getDrawData().?, pass);
}

fn onEvent(event: platform.Event, _: platform.Window) !void {
    switch (event) {
        .window_close => should_run = false,
        .window_resize => |size| context.onWindowResize(size),
        else => {},
    }
    try canvas.onEvent(event);
    input.onEvent(event);
    input_gui.onEvent(event);
    try input_basic.onEvent(event, input_gui.isGrabbed());
    if (editor.grab) |grab| {
        if (try grab.onEvent(event))
            try editor.updateOperation();
    }
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
