const std = @import("std");
const math = @import("math");
const platform = @import("platform");

const canvas = @import("canvas.zig");
const input = @import("input.zig");

pub const AnyGrab = union(enum) {
    Position: Position,
    Offset: Offset,
    Angle: Angle,

    pub fn onEvent(grab: AnyGrab, event: platform.Event) !bool {
        return switch (grab) {
            inline else => |comptime_grab| comptime_grab.onEvent(event),
        };
    }
    pub fn cancel(grab: AnyGrab) void {
        return switch (grab) {
            inline else => |comptime_grab| comptime_grab.cancel(),
        };
    }
};

pub const Position = struct {
    pos: *math.Vec2,
    orig_pos: math.Vec2,

    pub fn init(pos: *math.Vec2) Position {
        return .{ .pos = pos, .orig_pos = pos.* };
    }

    pub fn onEvent(grab: Position, event: platform.Event) !bool {
        switch (event) {
            .mouse_move => {
                grab.pos.* = canvas.mousePos();
                return true;
            },
            else => return false,
        }
    }

    pub fn cancel(grab: Position) void {
        grab.pos.* = grab.orig_pos;
    }
};

pub const Offset = struct {
    offset: *math.Vec2,
    orig_offset: math.Vec2,

    pub fn init(offset: *math.Vec2) Offset {
        return .{ .offset = offset, .orig_offset = offset.* };
    }

    pub fn onEvent(grab: Offset, event: platform.Event) !bool {
        switch (event) {
            .mouse_move => {
                const multiplier: f32 = if (input.isShiftPressed()) 0.1 else 1;
                grab.offset.* += canvas.mouseOffset() * math.vec2.splat(multiplier);
                return true;
            },
            else => return false,
        }
    }

    pub fn cancel(grab: Offset) void {
        grab.offset.* = grab.orig_offset;
    }
};

pub const Angle = struct {
    angle: *f32,
    orig_angle: f32,
    pos_a: math.Vec2,
    pos_b: math.Vec2,

    pub fn init(angle: *f32, pos_a: math.Vec2, pos_b: math.Vec2) Angle {
        return .{ .angle = angle, .orig_angle = angle.*, .pos_a = pos_a, .pos_b = pos_b };
    }

    pub fn onEvent(grab: Angle, event: platform.Event) !bool {
        switch (event) {
            .mouse_move => {
                grab.angle.* = math.Arc.angleOnPoint(.{ .pos_a = grab.pos_a, .pos_b = grab.pos_b }, canvas.mousePos());
                return true;
            },
            else => return false,
        }
    }

    pub fn cancel(grab: Angle) void {
        grab.angle.* = grab.orig_angle;
    }
};
