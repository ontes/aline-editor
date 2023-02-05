const std = @import("std");
const platform = @import("platform");
const render = @import("render");
const webgpu = @import("webgpu");

const editor = @import("editor.zig");
const canvas = @import("canvas.zig");
const input = @import("input.zig");
const gui = @import("gui.zig");

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
    gui.init(context.device);

    time = std.time.nanoTimestamp();
}

fn deinit() void {
    editor.deinit();
    gui.deinit();

    for (buffers) |*buffer|
        buffer.deinit();
    context.deinit();

    window.destroy();
    platform.deinit();
}

fn onFrame() !void {
    try platform.pollEvents(onEvent);

    try gui.onFrame();

    if (editor.should_draw_canvas) {
        buffers[0].clear();
        try canvas.draw(&buffers[0]);
        buffers[0].flush();
        editor.should_draw_canvas = false;
    }
    if (editor.should_draw_image) {
        buffers[1].clear();
        try editor.drawImage(&buffers[1]);
        buffers[1].flush();
        editor.should_draw_image = false;
    }
    if (editor.should_draw_helper) {
        buffers[2].clear();
        try editor.drawHelper(&buffers[2]);
        buffers[2].flush();
        editor.should_draw_helper = false;
    }
    if (editor.should_update_transform) {
        for (buffers) |*buffer|
            buffer.setTransform(canvas.transform());
        editor.should_update_transform = false;
    }

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
    gui.render(pass);
}

fn onEvent(event: platform.Event, _: platform.Window) !void {
    switch (event) {
        .window_close => should_run = false,
        .window_resize => |size| context.onWindowResize(size),
        else => {},
    }
    try canvas.onEvent(event);
    gui.onEvent(event);
    try input.onEvent(event);
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
