const std = @import("std");
const math = @import("math");
const platform = @import("platform");
const editor = @import("editor.zig");

var window_size: [2]u32 = .{ 0, 0 };
var mouse_pos: [2]i32 = .{ 0, 0 };

var mouse_middle_pressed: bool = false;
var ctrl_pressed: bool = false;
var shift_pressed: bool = false;
var alt_pressed: bool = false;

var prev_mouse_canvas_pos: math.Vec2 = .{ 0, 0 };
pub var canvas_pan: math.Vec2 = .{ 0, 0 };
pub var canvas_zoom: f32 = 1;

pub fn onEvent(event: platform.Event) void {
    switch (event) {
        .key_press, .key_release => |key| {
            const pressed = (event == .key_press);
            switch (key) {
                .left_ctrl, .right_ctrl => ctrl_pressed = pressed,
                .left_shift, .right_shift => shift_pressed = pressed,
                .left_alt, .right_alt => alt_pressed = pressed,
                .mouse_middle => mouse_middle_pressed = pressed,
                else => {},
            }
        },
        .window_resize => |size| window_size = size,
        .mouse_move => |pos| {
            prev_mouse_canvas_pos = mouseCanvasPos();
            mouse_pos = pos;
        },
        else => {},
    }
}

pub fn mousePos() math.Vec2 {
    return .{
        @intToFloat(f32, mouse_pos[0]) - @intToFloat(f32, window_size[0]) / 2,
        @intToFloat(f32, window_size[1]) / 2 - @intToFloat(f32, mouse_pos[1]),
    };
}
pub fn windowSize() math.Vec2 {
    return .{ @intToFloat(f32, window_size[0]), @intToFloat(f32, window_size[1]) };
}

pub fn mouseCanvasPos() math.Vec2 {
    return canvas_pan + math.vec2.splat(canvas_zoom) * mousePos();
}
pub fn mouseCanvasOffset() math.Vec2 {
    return mouseCanvasPos() - prev_mouse_canvas_pos;
}

pub fn isCtrlPressed() bool {
    return ctrl_pressed;
}
pub fn isShiftPressed() bool {
    return shift_pressed;
}
pub fn isAltPressed() bool {
    return alt_pressed;
}
pub fn isMouseMiddlePressed() bool {
    return mouse_middle_pressed;
}

pub fn canvasTransform() math.Mat3 {
    const scale = math.vec2.splat(2 / canvas_zoom) / windowSize();
    return math.mat3.mult(math.mat3.scale(.{ scale[0], scale[1], 1 }), math.mat3.translate(-canvas_pan));
}

pub fn standardTransform() math.Mat3 {
    const scale = math.vec2.splat(2) / windowSize();
    return math.mat3.scale(.{ scale[0], scale[1], 1 });
}

pub fn standardStroke() math.Stroke {
    return .{ .width = 2 * canvas_zoom, .cap = .round };
}
pub fn wideStroke() math.Stroke {
    return .{ .width = 4 * canvas_zoom, .cap = .round };
}
pub fn snapDist() f32 {
    return 10 * canvas_zoom;
}
