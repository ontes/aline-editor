const std = @import("std");
const platform = @import("platform.zig");

pub var keys: [256]bool = .{false} ** 256;
pub var mouse_pos: [2]f32 = .{ 0, 0 };
pub var mouse_scroll: i32 = 0;
pub var mouse_inside: bool = false;
pub var window_size: [2]u32 = .{ 0, 0 };

pub fn onEvent(event: platform.Event) void {
    switch (event) {
        .key_press => |key| keys[@enumToInt(key)] = true,
        .key_release => |key| keys[@enumToInt(key)] = false,
        .mouse_move => |pos| mouse_pos = mousePosToRelative(pos),
        .mouse_scroll => |offset| mouse_scroll += offset,
        .mouse_enter => mouse_inside = true,
        .mouse_leave => mouse_inside = false,
        .window_resize => |size| window_size = size,
        else => {},
    }
}

pub fn isPressed(key: platform.Key) bool {
    return keys[@enumToInt(key)];
}

fn mousePosToRelative(pos: [2]i32) [2]f32 {
    return .{
        @intToFloat(f32, pos[0]) / @intToFloat(f32, window_size[0]) * 2 - 1,
        @intToFloat(f32, pos[1]) / @intToFloat(f32, window_size[1]) * -2 + 1,
    };
}
