const std = @import("std");
const platform = @import("platform.zig");
const render = @import("render.zig");
const geometry = @import("geometry.zig");
const input = @import("input.zig");
const editor = @import("editor.zig");
const timer = @import("timer.zig");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};

var window: platform.Window = undefined;
var context: render.Context = undefined;

pub var main_buffer: render.Buffer = undefined;
pub var tool_buffer: render.Buffer = undefined;

var should_run = true;

fn init() !void {
    try platform.init();
    window = try platform.Window.create(.{ 0, 0 }, .{ 1000, 1000 }, "Aline Editor");
    window.show();

    context = try render.Context.init(window);
    main_buffer = render.Buffer.init(context, gpa.allocator());
    tool_buffer = render.Buffer.init(context, gpa.allocator());

    editor.init(gpa.allocator());
    timer.update();
}

fn deinit() void {
    editor.deinit();

    main_buffer.deinit();
    tool_buffer.deinit();
    context.deinit();

    window.destroy();
    platform.deinit();

    _ = gpa.deinit();
}

fn update() !void {
    timer.update();
    if (timer.oncePerMs(1000))
        std.debug.print("FPS: {}\n", .{timer.fps()});
    try platform.update(onEvent);
    try editor.update();
    context.update(&.{ main_buffer, tool_buffer });
}

fn onEvent(event: platform.Event, _: platform.Window) !void {
    switch (event) {
        .window_close => should_run = false,
        .window_resize => |size| context.updateSize(size),
        else => {},
    }
    input.onEvent(event);
    try editor.onEvent(event);
}

pub fn main() !void {
    try init();
    defer deinit();
    while (should_run)
        try update();
}
