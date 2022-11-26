const std = @import("std");
const geometry = @import("../geometry.zig");
const platform = @import("../platform.zig");

var window_size: [2]u32 = .{ 0, 0 };
var mouse_pos: [2]i32 = .{ 0, 0 };
var ctrl_pressed: bool = false;
var shift_pressed: bool = false;
var alt_pressed: bool = false;

pub fn onEvent(event: platform.Event) void {
    switch (event) {
        .key_press, .key_release => |key| {
            const pressed = (event == .key_press);
            switch (key) {
                .left_ctrl, .right_ctrl => ctrl_pressed = pressed,
                .left_shift, .right_shift => shift_pressed = pressed,
                .left_alt, .right_alt => alt_pressed = pressed,
                else => {},
            }
        },
        .mouse_move => |pos| mouse_pos = pos,
        .window_resize => |size| window_size = size,
        else => {},
    }
}

fn windowPosToCanvasPos(pos: [2]i32) geometry.Vec2 {
    return .{
        @intToFloat(f32, pos[0]),
        @intToFloat(f32, window_size[1]) - @intToFloat(f32, pos[1]),
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

pub fn windowSize() [2]u32 {
    return window_size;
}
