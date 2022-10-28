const std = @import("std");
const platform = @import("platform.zig");
const render = @import("render.zig");
const geometry = @import("geometry.zig");
const input = @import("input.zig");
const editor = @import("editor.zig");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};

var window: platform.Window = undefined;
var context: render.Context = undefined;

pub var main_buffer: render.Buffer = undefined;
pub var tool_buffer: render.Buffer = undefined;
pub var snap_grid_buffer: render.Buffer = undefined;

pub var vertices: geometry.Vertices = undefined;
pub var indices: geometry.Indices = undefined;

var should_run = true;

fn init() !void {
    try platform.init();
    window = try platform.Window.create(.{ 0, 0 }, .{ 1000, 1000 }, "Aline Editor");
    window.show();

    context = try render.Context.init(window);
    main_buffer = render.Buffer.init(context);
    tool_buffer = render.Buffer.init(context);
    snap_grid_buffer = render.Buffer.init(context);

    vertices = geometry.Vertices.init(gpa.allocator());
    indices = geometry.Indices.init(gpa.allocator());

    editor.init(gpa.allocator());
}

fn deinit() void {
    editor.deinit();

    vertices.deinit();
    indices.deinit();

    main_buffer.deinit();
    tool_buffer.deinit();
    snap_grid_buffer.deinit();
    context.deinit();

    window.destroy();
    platform.deinit();

    _ = gpa.deinit();
}

fn update() !void {
    try platform.pollEvents(onEvent);
    try editor.update();
    context.update(&.{ snap_grid_buffer, main_buffer, tool_buffer });
    std.time.sleep(16 * std.time.ns_per_ms);
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
