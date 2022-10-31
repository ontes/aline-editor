const std = @import("std");
const geometry = @import("geometry.zig");
const render = @import("render.zig");
const platform = @import("platform.zig");

pub var objects_buffer: render.Buffer = undefined;

pub const Object = struct {
    allocator: std.mem.Allocator,
    positions: std.ArrayListUnmanaged(geometry.Vec2) = .{},
    angles: std.ArrayListUnmanaged(f32) = .{},
    color: [4]u8 = .{ 32, 32, 32, 255 },
    stroke: geometry.Stroke = .{ .width = 0.005, .cap = .round },
    stroke_color: [4]u8 = .{ 255, 255, 255, 255 },

    pub inline fn toPath(object: Object) geometry.Path {
        return .{ .positions = object.positions.items, .angles = object.angles.items };
    }

    pub fn init(allocator: std.mem.Allocator, first_pos: geometry.Vec2) !Object {
        var path = Object{ .allocator = allocator };
        try path.positions.append(allocator, first_pos);
        return path;
    }

    pub fn deinit(object: *Object) void {
        object.positions.deinit(object.allocator);
        object.angles.deinit(object.allocator);
    }

    pub fn gen(object: Object, buffer: *render.Buffer) !void {
        const path = object.toPath();
        if (path.isLooped())
            try path.gen(object.color, buffer);
        try object.stroke.genPath(path, object.stroke_color, buffer);
    }

    pub fn append(object: *Object, pos: geometry.Vec2, angle: f32) !void {
        std.debug.assert(!object.toPath().isLooped());
        try object.positions.append(object.allocator, pos);
        try object.angles.append(object.allocator, angle);
    }

    pub fn loop(object: *Object, angle: f32) !void {
        std.debug.assert(!object.toPath().isLooped());
        try object.angles.append(object.allocator, angle);
    }

    pub fn reverse(object: *Object) void {
        std.mem.reverse(geometry.Vec2, object.positions.items);
        const loop_angle = if (object.toPath().isLooped()) object.angles.pop() else null;
        std.mem.reverse(f32, object.angles.items);
        if (loop_angle) |angle| object.angles.appendAssumeCapacity(angle);
        for (object.angles.items) |*angle|
            angle.* = -angle.*;
    }

    pub fn rotate(object: *Object, amount: usize) void {
        std.debug.assert(object.toPath().isLooped());
        std.mem.rotate(geometry.Vec2, object.positions.items, amount);
        std.mem.rotate(f32, object.angles.items, amount);
    }

    pub fn clone(object: *Object) !Object {
        var path_clone = object.*;
        path_clone.positions = try object.positions.clone(object.allocator);
        path_clone.angles = try object.angles.clone(object.allocator);
        return path_clone;
    }
};
pub var objects: std.ArrayList(Object) = undefined;

pub fn init(allocator: std.mem.Allocator, context: render.Context) void {
    objects = std.ArrayList(Object).init(allocator);
    objects_buffer = render.Buffer.init(context, allocator);
}

pub fn deinit() void {
    for (objects.items) |*object| object.deinit();
    objects.deinit();
    objects_buffer.deinit();
}

pub fn updateObjectsBuffer() !void {
    objects_buffer.clear();
    for (objects.items) |*object|
        try object.gen(&objects_buffer);
    objects_buffer.flush();
}

var window_size = [2]u32{ 0, 0 };

pub fn onWindowResize(size: [2]u32) void {
    window_size = size;
}

pub fn toCanvasPos(pos: [2]i32) [2]f32 {
    return .{
        @intToFloat(f32, pos[0]) / @intToFloat(f32, window_size[0]) * 2 - 1,
        @intToFloat(f32, pos[1]) / @intToFloat(f32, window_size[1]) * -2 + 1,
    };
}
