const std = @import("std");
const editor = @import("../editor.zig");
const geometry = @import("../geometry.zig");
const platform = @import("../platform.zig");
const vec2 = @import("../linalg.zig").vec(2, f32);
const mat3 = @import("../linalg.zig").mat(3, f32);

var window_size: [2]u32 = .{ 0, 0 };
var mouse_pos: [2]i32 = .{ 0, 0 };
var prev_mouse_pos: [2]i32 = .{ 0, 0 };

var mouse_middle_pressed: bool = false;
var ctrl_pressed: bool = false;
var shift_pressed: bool = false;
var alt_pressed: bool = false;

pub var canvas_pan: geometry.Vec2 = .{ 0, 0 };
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
            prev_mouse_pos = mouse_pos;
            mouse_pos = pos;
        },
        else => {},
    }
}

fn windowPosToCanvasPos(pos: [2]i32) geometry.Vec2 {
    return canvas_pan + vec2.splat(canvas_zoom) * geometry.Vec2{
        @intToFloat(f32, pos[0]) - @intToFloat(f32, window_size[0]) / 2,
        @intToFloat(f32, window_size[1]) / 2 - @intToFloat(f32, pos[1]),
    };
}

fn windowPosToRelWinPos(pos: [2]i32) geometry.Vec2 {
    return .{
        @intToFloat(f32, pos[0]) / @intToFloat(f32, window_size[0]),
        @intToFloat(f32, pos[1]) / @intToFloat(f32, window_size[1]),
    };
}

pub fn mouseCanvasPos() geometry.Vec2 {
    return windowPosToCanvasPos(mouse_pos);
}

pub fn mouseCanvasOffset() geometry.Vec2 {
    return windowPosToCanvasPos(mouse_pos) - windowPosToCanvasPos(prev_mouse_pos);
}

pub fn mouseRelWinPos() geometry.Vec2 {
    return windowPosToRelWinPos(mouse_pos);
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

pub fn getTransform() mat3.Matrix {
    return mat3.mult(
        mat3.scale(.{ 2 / canvas_zoom / @intToFloat(f32, window_size[0]), 2 / canvas_zoom / @intToFloat(f32, window_size[1]), 1 }),
        mat3.translate(-canvas_pan),
    );
}

pub fn standardStroke() geometry.Stroke {
    return .{ .width = 2 * canvas_zoom, .cap = .round };
}
pub fn wideStroke() geometry.Stroke {
    return .{ .width = 4 * canvas_zoom, .cap = .round };
}
pub fn snapDist() f32 {
    return 10 * canvas_zoom;
}
