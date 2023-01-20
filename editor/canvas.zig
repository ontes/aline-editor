const std = @import("std");
const math = @import("math");
const platform = @import("platform");
const render = @import("render");

const editor = @import("editor.zig");

var window_size: math.Vec2 = .{ 0, 0 };
var mouse_pos: math.Vec2 = .{ 0, 0 };
var prev_mouse_pos: math.Vec2 = .{ 0, 0 };
var mouse_middle_pressed: bool = false;

var canvas_pan: math.Vec2 = .{ 0, 0 };
var canvas_zoom: f32 = 1;
const canvas_size = math.Vec2{ 512, 512 };
const canvas_corner_radius: f32 = 16;

pub fn onEvent(event: platform.Event) !void {
    switch (event) {
        .key_press, .key_release => |key| switch (key) {
            .mouse_middle => mouse_middle_pressed = (event == .key_press),
            else => {},
        },
        .window_resize => |size| {
            window_size = .{
                @intToFloat(f32, size[0]),
                @intToFloat(f32, size[1]),
            };
            editor.should_update_transform = true;
            editor.should_draw_helper = true;
        },
        .mouse_move => |pos| {
            prev_mouse_pos = mouse_pos;
            mouse_pos = canvas_pan + math.vec2.splat(canvas_zoom) * math.Vec2{
                @intToFloat(f32, pos[0]) - window_size[0] / 2,
                window_size[1] / 2 - @intToFloat(f32, pos[1]),
            };
            if (mouse_middle_pressed) {
                canvas_pan -= mouseOffset();
                editor.should_update_transform = true;
            }
        },
        .mouse_scroll => |offset| {
            canvas_zoom *= std.math.pow(f32, 0.8, @intToFloat(f32, offset));
            editor.should_update_transform = true;
            editor.should_draw_helper = true;
        },
        else => {},
    }
}

pub fn draw(buffer: *render.Buffer) !void {
    const rect = math.RoundedRect{
        .pos = .{ 0, 0 },
        .radius = canvas_size / math.vec2.splat(2),
        .corner_radius = canvas_corner_radius,
    };
    try rect.generate(buffer.generator(.{ 255, 255, 255, 255 }));
}

pub fn mousePos() math.Vec2 {
    return mouse_pos;
}
pub fn mouseOffset() math.Vec2 {
    return mouse_pos - prev_mouse_pos;
}

pub fn transform() math.Mat3 {
    const scale = math.vec2.splat(2 / canvas_zoom) / window_size;
    return math.mat3.mult(math.mat3.scale(.{ scale[0], scale[1], 1 }), math.mat3.translate(-canvas_pan));
}

pub fn stroke() math.Stroke {
    return .{ .width = 2 * canvas_zoom, .cap = .round };
}
pub fn wideStroke() math.Stroke {
    return .{ .width = 4 * canvas_zoom, .cap = .round };
}
pub fn snapDist() f32 {
    return 10 * canvas_zoom;
}
