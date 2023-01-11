const std = @import("std");
const render = @import("../render.zig");
const geometry = @import("../geometry.zig");
const platform = @import("../platform.zig");
const editor = @import("../editor.zig");
const state = @import("state.zig");
const Drawing = @import("Drawing.zig");
const Selection = @import("Selection.zig");

pub const Position = struct {
    val: geometry.Vec2,
    grab: ?struct {
        old_val: geometry.Vec2,
    } = null,

    pub fn isGrabbed(prop: Position) bool {
        return prop.grab != null;
    }

    pub fn beginGrab(prop: *Position) void {
        prop.grab = .{ .old_val = prop.val };
        prop.val = state.mouseCanvasPos();
    }

    pub fn finishGrab(prop: *Position) void {
        prop.grab = null;
    }

    pub fn cancelGrab(prop: *Position) void {
        prop.val = prop.grab.?.old_val;
        prop.grab = null;
    }

    pub fn onEvent(prop: *Position, event: platform.Event) !void {
        if (prop.isGrabbed()) {
            switch (event) {
                .mouse_move => {
                    prop.val = state.mouseCanvasPos();
                    try editor.updateOperation();
                },
                .key_release => |key| switch (key) {
                    .mouse_left => {
                        prop.finishGrab();
                        try editor.updateOperation();
                    },
                    .mouse_right => {
                        prop.cancelGrab();
                        try editor.updateOperation();
                    },
                    else => {},
                },
                else => {},
            }
        }
    }
};

pub const Offset = struct {
    val: geometry.Vec2 = .{ 0, 0 },
    grab: ?struct {
        old_val: geometry.Vec2,
        prev_mouse_pos: geometry.Vec2,
    } = null,

    pub fn isGrabbed(prop: Offset) bool {
        return prop.grab != null;
    }

    pub fn beginGrab(prop: *Offset) void {
        prop.grab = .{ .old_val = prop.val, .prev_mouse_pos = state.mouseCanvasPos() };
    }

    pub fn finishGrab(prop: *Offset) void {
        prop.grab = null;
    }

    pub fn cancelGrab(prop: *Offset) void {
        prop.val = prop.grab.?.old_val;
        prop.grab = null;
    }

    pub fn onEvent(prop: *Offset, event: platform.Event) !void {
        if (prop.grab) |*grab| {
            switch (event) {
                .mouse_move => {
                    const mouse_pos = state.mouseCanvasPos();
                    const multiplier: f32 = if (state.isShiftPressed()) 0.1 else 1;
                    prop.val += (mouse_pos - grab.prev_mouse_pos) * @splat(2, multiplier);
                    grab.prev_mouse_pos = mouse_pos;
                    try editor.updateOperation();
                },
                .key_release => |key| switch (key) {
                    .mouse_left => {
                        prop.finishGrab();
                        try editor.updateOperation();
                    },
                    .mouse_right => {
                        prop.cancelGrab();
                        try editor.updateOperation();
                    },
                    else => {},
                },
                else => {},
            }
        }
    }
};

pub const Angle = struct {
    val: f32 = 0,
    grab: ?struct {
        old_val: f32,
        prev_mouse_pos: f32,
    } = null,

    pub fn isGrabbed(prop: Angle) bool {
        return prop.grab != null;
    }

    pub fn beginGrab(prop: *Angle) void {
        prop.grab = .{ .old_val = prop.val, .prev_mouse_pos = state.mousePos()[1] / state.windowSize()[1] };
    }

    pub fn finishGrab(prop: *Angle) void {
        prop.grab = null;
    }

    pub fn cancelGrab(prop: *Angle) void {
        prop.val = prop.grab.?.old_val;
        prop.grab = null;
    }

    pub fn onEvent(prop: *Angle, event: platform.Event) !void {
        if (prop.grab) |*grab| {
            switch (event) {
                .mouse_move => {
                    const mouse_pos = state.mousePos()[1] / state.windowSize()[1];
                    const multiplier: f32 = if (state.isShiftPressed()) 0.1 else 1;
                    prop.val = 2 * std.math.atan(@tan(prop.val / 2) + (mouse_pos - grab.prev_mouse_pos) * 5 * multiplier);
                    grab.prev_mouse_pos = mouse_pos;
                    try editor.updateOperation();
                },
                .key_release => |key| switch (key) {
                    .mouse_left => {
                        prop.finishGrab();
                        try editor.updateOperation();
                    },
                    .mouse_right => {
                        prop.cancelGrab();
                        try editor.updateOperation();
                    },
                    else => {},
                },
                else => {},
            }
        }
    }
};
