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
var fps: u32 = 0;

var prng = std.rand.DefaultPrng.init(0);
var random: std.rand.Random = prng.random();

const triangles_in_step = 100;
var spawning: bool = true;
var real_time: bool = true;

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

    fps += 1;
    const current_time = std.time.nanoTimestamp();
    const frame_time = current_time - time;
    const frame_time_s = @intToFloat(f32, frame_time) / std.time.ns_per_s;

    if (@divFloor(current_time, std.time.ns_per_s) != @divFloor(time, std.time.ns_per_s)) {
        std.debug.print("Frametime: {}, FPS: {}\n", .{ frame_time_s, fps });
        std.debug.print("Editor path count: {}\n", .{editor.history.get().image.props.len});
        std.debug.print("Render path count: {}, Node count: {}\n", .{ rendering.image_buffer.path_count, rendering.image_buffer.data.len });
        std.debug.print("Spawning: {}, Real-time: {}\n", .{ spawning, real_time });
        std.debug.print("=====\n", .{});
        if (spawning and fps > 30)
            try addRandomTriangles();
        fps = 0;
    }
    time = std.time.nanoTimestamp();

    if (real_time)
        editor.should_draw_image = true;
}

fn addRandomTriangle() !void {
    const image = &editor.history.get().image;
    var pass = try image.generator(.{
        .stroke = .{ .width = 2, .cap = .round },
        .fill_color = .{ random.float(f32), random.float(f32), random.float(f32), random.float(f32) },
        .stroke_color = .{ 0, 0, 0, 1 },
    }, .{'T'} ++ .{0} ** 31).begin();
    var i: u32 = 0;
    while (i < 3) : (i += 1) {
        try pass.add(.{ (random.float(f32) - 0.5) * 512, (random.float(f32) - 0.5) * 512 }, random.float(f32) - 0.5);
    }
    try pass.end();
}

fn addRandomTriangles() !void {
    var i: u32 = 0;
    while (i < triangles_in_step) : (i += 1) {
        try addRandomTriangle();
    }
    editor.should_draw_image = true;
}

fn onEvent(event: platform.Event, _: platform.Window) !void {
    switch (event) {
        .window_resize => |size| rendering.context.onWindowResize(size),
        .key_press => |key| switch (key) {
            .t => spawning = !spawning,
            .o => real_time = !real_time,
            else => {},
        },
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
