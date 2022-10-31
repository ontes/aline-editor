const std = @import("std");
const platform = @import("platform.zig");
const render = @import("render.zig");
const canvas = @import("canvas.zig");
const history = @import("history.zig");
const tools = @import("tools.zig");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
var window: platform.Window = undefined;
var context: render.Context = undefined;

var should_run = true;

var ctrl_pressed = false;

const timer = struct {
    var prev_time: u128 = 0;
    var time: u128 = 0;
    var frames_per_second: u32 = 0;
    var frame_counter: u32 = 0;

    fn update() void {
        prev_time = time;
        time = @intCast(u128, std.time.nanoTimestamp());

        frame_counter += 1;
        if (oncePerMs(1000)) {
            frames_per_second = frame_counter;
            frame_counter = 0;
        }
    }

    inline fn deltaNs() u128 {
        return time - prev_time;
    }
    inline fn deltaMs() u64 {
        return deltaNs() / std.time.ns_per_ms;
    }
    inline fn deltaSeconds() f32 {
        return @intToFloat(f32, deltaMs()) / 1000;
    }
    inline fn oncePerNs(interval: u128) bool {
        return (time / interval) != (prev_time / interval);
    }
    inline fn oncePerMs(interval: u64) bool {
        return oncePerNs(interval * std.time.ns_per_ms);
    }
};

fn init() !void {
    timer.update();
    try platform.init();
    window = try platform.Window.create(.{ 0, 0 }, .{ 1000, 1000 }, "Aline Editor");
    window.show();
    context = try render.Context.init(window);

    canvas.init(gpa.allocator(), context);
    tools.init(gpa.allocator(), context);
    history.init(gpa.allocator());
}

fn deinit() void {
    canvas.deinit();
    tools.deinit();
    history.deinit();

    context.deinit();
    window.destroy();
    platform.deinit();
    _ = gpa.deinit();
}

fn update() !void {
    timer.update();
    if (timer.oncePerMs(1000))
        std.debug.print("FPS: {}\n", .{timer.frames_per_second});
    try platform.update(onEvent);
    context.update(&.{ canvas.objects_buffer, tools.tool_buffer });
}

fn onEvent(event: platform.Event, _: platform.Window) !void {
    switch (event) {
        .window_close => should_run = false,
        .window_resize => |size| {
            context.onWindowResize(size);
            canvas.onWindowResize(size);
        },
        .mouse_move => |pos| try tools.onMouseMove(canvas.toCanvasPos(pos)),
        .key_press => |key| switch (key) {
            .mouse_left => {
                try tools.onMousePress();
            },
            .z => {
                if (ctrl_pressed) {
                    try history.undo();
                    tools.reset();
                }
            },
            .y => {
                if (ctrl_pressed) {
                    try history.redo();
                    tools.reset();
                }
            },
            .left_shift, .right_shift => tools.onShiftPress(),
            .left_ctrl, .right_ctrl => ctrl_pressed = true,
            else => {},
        },
        .key_release => |key| switch (key) {
            .mouse_left => try tools.onMouseRelease(),
            .mouse_right => _ = try tools.setTool(.select),
            .a => _ = try tools.setTool(.append),
            .g => _ = try tools.setTool(.move),
            .d => _ = try tools.setTool(.change_angle),
            .s => _ = try tools.setTool(.split),
            .left_shift, .right_shift => tools.onShiftRelease(),
            .left_ctrl, .right_ctrl => ctrl_pressed = false,
            else => {},
        },
        else => {},
    }
}

pub fn main() !void {
    try init();
    defer deinit();
    while (should_run)
        try update();
}
