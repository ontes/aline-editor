const std = @import("std");
const platform = @import("platform");

const editor = @import("editor.zig");
const input = @import("input.zig");
const gui = @import("gui.zig");
const rendering = @import("rendering.zig");
const storage = @import("storage.zig");

const desired_frame_time = 10 * std.time.ns_per_ms;

var window: platform.Window = undefined;
var time: i128 = undefined;

fn init(allocator: std.mem.Allocator) !void {
    try platform.init();
    window = try platform.Window.create(.{ 0, 0 }, .{ 1280, 720 }, "Aline Editor");
    window.show();

    try rendering.init(window, allocator);
    try editor.init(allocator);
    gui.init(rendering.context.device);

    time = std.time.nanoTimestamp();
}

fn deinit() void {
    editor.deinit();
    gui.deinit();
    rendering.deinit();
    storage.deinit();
    window.destroy();
    platform.deinit();
}

fn onFrame() !void {
    try platform.pollEvents(onEvent);
    try gui.onFrame();
    try editor.onFrame();

    rendering.renderToScreen();

    const frame_time = std.time.nanoTimestamp() - time;
    if (frame_time < desired_frame_time)
        std.time.sleep(@intCast(u64, desired_frame_time - frame_time));
    time = std.time.nanoTimestamp();
}

fn onEvent(event: platform.Event, _: platform.Window) !void {
    switch (event) {
        .window_resize => |size| rendering.context.onWindowResize(size),
        else => {},
    }
    gui.onEvent(event);
    try input.onEvent(event);
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    try init(gpa.allocator());
    defer deinit();

    while (editor.should_run) {
        try onFrame();
    }
}
