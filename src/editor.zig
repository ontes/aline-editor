const std = @import("std");
const root = @import("root");
const platform = @import("platform.zig");
const render = @import("render.zig");
const geometry = @import("geometry.zig");
const input = @import("input.zig");
const history = @import("history.zig");

pub const Object = struct {
    allocator: std.mem.Allocator,
    positions: std.ArrayListUnmanaged([2]f32) = .{},
    angles: std.ArrayListUnmanaged(f32) = .{},
    color: [4]u8 = .{ 32, 32, 32, 255 },
    stroke: geometry.Stroke = .{ .width = 0.005, .cap = .round },
    stroke_color: [4]u8 = .{ 255, 255, 255, 255 },

    pub inline fn toPath(object: Object) geometry.Path {
        return .{ .positions = object.positions.items, .angles = object.angles.items };
    }

    pub fn init(allocator: std.mem.Allocator, first_pos: [2]f32) !Object {
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

    pub fn append(object: *Object, pos: [2]f32, angle: f32) !void {
        std.debug.assert(!object.toPath().isLooped());
        try object.positions.append(object.allocator, pos);
        try object.angles.append(object.allocator, angle);
    }

    pub fn loop(object: *Object, angle: f32) !void {
        std.debug.assert(!object.toPath().isLooped());
        try object.angles.append(object.allocator, angle);
    }

    pub fn reverse(object: *Object) void {
        std.mem.reverse([2]f32, object.positions.items);
        const loop_angle = if (object.toPath().isLooped()) object.angles.pop() else null;
        std.mem.reverse(f32, object.angles.items);
        if (loop_angle) |angle| object.angles.appendAssumeCapacity(angle);
        for (object.angles.items) |*angle|
            angle.* = -angle.*;
    }

    pub fn rotate(object: *Object, amount: usize) void {
        std.debug.assert(object.toPath().isLooped());
        std.mem.rotate([2]f32, object.positions.items, amount);
        std.mem.rotate(f32, object.angles.items, amount);
    }

    pub fn clone(object: *Object) !Object {
        var path_clone = object.*;
        path_clone.positions = try object.positions.clone(object.allocator);
        path_clone.angles = try object.angles.clone(object.allocator);
        return path_clone;
    }
};

pub const Node = struct {
    object_index: u32,
    index: u32,

    pub inline fn getObject(node: Node) *Object {
        return &objects.items[node.object_index];
    }

    pub inline fn getPath(node: Node) geometry.Path {
        return getObject(node).toPath();
    }

    pub inline fn prev(node: Node) ?Node {
        return if (node.getPath().prevIndex(node.index)) |prev_index| .{ .object_index = node.object_index, .index = prev_index } else null;
    }

    pub inline fn next(node: Node) ?Node {
        return if (node.getPath().nextIndex(node.index)) |next_index| .{ .object_index = node.object_index, .index = next_index } else null;
    }

    pub inline fn getPos(node: Node) [2]f32 {
        return node.getPath().getPos(node.index);
    }

    pub inline fn getAngleFrom(node: Node) ?f32 {
        return node.getPath().getAngleFrom(node.index);
    }

    pub inline fn getAngleTo(node: Node) ?f32 {
        return node.getPath().getAngleTo(node.index);
    }

    pub inline fn getArcFrom(node: Node) ?geometry.Arc {
        return node.getPath().getArcFrom(node.index);
    }

    pub inline fn getArcTo(node: Node) ?geometry.Arc {
        return node.getPath().getArcTo(node.index);
    }
};

pub const Mode = enum {
    select,
    append,
    move,
    change_angle,

    fn namespace(comptime md: Mode) type {
        return switch (md) {
            .select => @import("modes/select.zig"),
            .append => @import("modes/append.zig"),
            .move => @import("modes/move.zig"),
            .change_angle => @import("modes/change_angle.zig"),
        };
    }

    fn canInit(m: Mode) bool {
        switch (m) {
            inline else => |cm| return cm.namespace().canInit(),
        }
    }
    fn init(m: Mode) !void {
        switch (m) {
            inline else => |cm| try cm.namespace().init(),
        }
    }
    fn deinit(m: Mode) void {
        switch (m) {
            inline else => |cm| cm.namespace().deinit(),
        }
    }
    fn gen(m: Mode, buffer: *render.Buffer) !void {
        switch (m) {
            inline else => |cm| try cm.namespace().gen(buffer),
        }
    }
    fn onEvent(m: Mode, event: platform.Event) !void {
        switch (m) {
            inline else => |cm| try cm.namespace().onEvent(event),
        }
    }
};

pub var objects: std.ArrayList(Object) = undefined;
pub var selected_nodes: std.ArrayList(Node) = undefined;
pub var mode: Mode = .select;

pub fn init(allocator: std.mem.Allocator) void {
    objects = std.ArrayList(Object).init(allocator);
    selected_nodes = std.ArrayList(Node).init(allocator);
    history.init(allocator);
}

pub fn deinit() void {
    for (objects.items) |*path| path.deinit();
    objects.deinit();
    selected_nodes.deinit();
    history.deinit();
}

pub fn update() !void {
    root.tool_buffer.clear();
    try mode.gen(&root.tool_buffer);
    root.tool_buffer.flush();
}

fn genObjects() !void {
    root.main_buffer.clear();
    for (objects.items) |*path|
        try path.gen(&root.main_buffer);
    root.main_buffer.flush();
}

pub fn step() !void {
    try history.step();
    try genObjects();
}

pub fn onEvent(event: platform.Event) !void {
    switch (event) {
        .key_press => |key| switch (key) {
            .z, .y => {
                if (input.isPressed(.left_ctrl) or input.isPressed(.right_ctrl)) {
                    selected_nodes.clearRetainingCapacity();
                    _ = try setMode(.select);
                    if (key == .z) try history.undo() else try history.redo();
                    try genObjects();
                }
            },
            .a => _ = try setMode(.append),
            .g => _ = try setMode(.move),
            .d => _ = try setMode(.change_angle),
            else => {},
        },
        else => {},
    }
    try mode.onEvent(event);
}

pub fn setMode(new_mode: Mode) !bool {
    if (!new_mode.canInit())
        return false;
    mode.deinit();
    mode = new_mode;
    try mode.init();
    return true;
}

pub fn findSelected(node: Node) ?u32 {
    for (selected_nodes.items) |selected_node, node_index| {
        if (selected_node.object_index == node.object_index and selected_node.index == node.index)
            return @intCast(u32, node_index);
    }
    return null;
}

pub inline fn isSelected(node: Node) bool {
    return findSelected(node) != null;
}
