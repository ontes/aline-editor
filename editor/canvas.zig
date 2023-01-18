const std = @import("std");
const math = @import("math");
const platform = @import("platform");
const render = @import("render");

const editor = @import("editor.zig");
const input = @import("input.zig");

var canvas_pan: math.Vec2 = .{ 0, 0 };
var canvas_zoom: f32 = 1;
const canvas_size = math.Vec2{ 512, 512 };
const canvas_corner_radius: f32 = 16;

var prev_mouse_pos: math.Vec2 = .{ 0, 0 };

pub fn onEvent(event: platform.Event) !void {
    switch (event) {
        .window_resize => {
            editor.should_update_transform = true;
            editor.should_draw_helper = true;
        },
        .mouse_move => {
            if (input.isMouseMiddlePressed()) {
                canvas_pan -= mouseOffset();
                editor.should_update_transform = true;
            }
            prev_mouse_pos = mousePos();
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
    return canvas_pan + math.vec2.splat(canvas_zoom) * input.mousePos();
}
pub fn mouseOffset() math.Vec2 {
    return mousePos() - prev_mouse_pos;
}

pub fn transform() math.Mat3 {
    const scale = math.vec2.splat(2 / canvas_zoom) / input.windowSize();
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
