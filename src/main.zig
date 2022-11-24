const std = @import("std");
const platform = @import("platform.zig");
const render = @import("render.zig");
const editor = @import("editor.zig");

const desired_frame_time = 10 * std.time.ns_per_ms;

var window: platform.Window = undefined;

var context: render.Context = undefined;
var main_buffer: render.Buffer = undefined;
var helper_buffer: render.Buffer = undefined;

var should_run = true;
var time: i128 = undefined;

fn init(allocator: std.mem.Allocator) !void {
    try platform.init();
    window = try platform.Window.create(.{ 0, 0 }, .{ 1000, 1000 }, "Aline Editor");
    window.show();

    context = try render.Context.init(window);
    main_buffer = render.Buffer.init(context, allocator);
    helper_buffer = render.Buffer.init(context, allocator);

    try editor.init(allocator);

    time = std.time.nanoTimestamp();
}

fn deinit() void {
    editor.deinit();
    main_buffer.deinit();
    helper_buffer.deinit();
    context.deinit();
    window.destroy();
    platform.deinit();
}

fn onFrame() !void {
    try platform.pollEvents(onEvent);

    if (try editor.draw(&main_buffer, &helper_buffer))
        context.draw(&.{ main_buffer, helper_buffer });

    const frame_time = std.time.nanoTimestamp() - time;
    if (frame_time < desired_frame_time)
        std.time.sleep(@intCast(u64, desired_frame_time - frame_time));
    time = std.time.nanoTimestamp();
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
