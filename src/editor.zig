const std = @import("std");
const root = @import("root");
const platform = @import("platform.zig");
const geometry = @import("geometry.zig");
const input = @import("input.zig");
const history = @import("history.zig");

pub const DynamicPath = struct {
    allocator: std.mem.Allocator,
    positions: std.ArrayListUnmanaged([2]f32) = .{},
    angles: std.ArrayListUnmanaged(f32) = .{},
    stroke: geometry.Stroke,

    pub fn init(allocator: std.mem.Allocator, first_pos: [2]f32, stroke: geometry.Stroke) !DynamicPath {
        var path = DynamicPath{ .allocator = allocator, .stroke = stroke };
        try path.positions.append(allocator, first_pos);
        return path;
    }

    pub fn deinit(path: *DynamicPath) void {
        path.positions.deinit(path.allocator);
        path.angles.deinit(path.allocator);
    }

    pub fn toPath(path: DynamicPath) geometry.Path {
        return .{
            .positions = path.positions.items,
            .angles = path.angles.items,
            .stroke = path.stroke,
        };
    }

    pub fn append(path: *DynamicPath, pos: [2]f32, angle: f32) !void {
        std.debug.assert(!path.toPath().isLooped());
        try path.positions.append(path.allocator, pos);
        try path.angles.append(path.allocator, angle);
    }

    pub fn loop(path: *DynamicPath, angle: f32) !void {
        std.debug.assert(!path.toPath().isLooped());
        try path.angles.append(path.allocator, angle);
    }

    pub fn reverse(path: *DynamicPath) void {
        std.mem.reverse([2]f32, path.positions.items);
        const loop_angle = if (path.toPath().isLooped()) path.angles.pop() else null;
        std.mem.reverse(f32, path.angles.items);
        if (loop_angle) |angle| path.angles.append(path.allocator, angle) catch unreachable;
        for (path.angles.items) |*angle|
            angle.* = -angle.*;
    }

    pub fn rotate(path: *DynamicPath, amount: usize) void {
        std.debug.assert(path.toPath().isLooped());
        std.mem.rotate([2]f32, path.positions.items, amount);
        std.mem.rotate(f32, path.angles.items, amount);
    }

    pub fn clone(path: *DynamicPath) !DynamicPath {
        var path_clone = path.*;
        path_clone.positions = try path.positions.clone(path.allocator);
        path_clone.angles = try path.angles.clone(path.allocator);
        return path_clone;
    }
};

pub const Node = struct {
    path_index: u32,
    index: u32,

    pub inline fn getDynamicPath(node: Node) *DynamicPath {
        return &paths.items[node.path_index];
    }

    pub inline fn getPath(node: Node) geometry.Path {
        return getDynamicPath(node).toPath();
    }

    pub inline fn getPos(node: Node) [2]f32 {
        return node.getPath().getPos(node.index);
    }

    pub inline fn getAngleFrom(node: Node) f32 {
        return node.getPath().getAngleFrom(node.index);
    }

    pub inline fn getAngleTo(node: Node) f32 {
        return node.getPath().getAngleTo(node.index);
    }

    pub inline fn prev(node: Node) ?Node {
        return .{ .path_index = node.path_index, .index = node.getPath().prevIndex(node.index) orelse return null };
    }

    pub inline fn next(node: Node) ?Node {
        return .{ .path_index = node.path_index, .index = node.getPath().nextIndex(node.index) orelse return null };
    }
};

pub const Mode = enum {
    select,
    append,
    move,

    fn namespace(comptime md: Mode) type {
        return switch (md) {
            .select => @import("modes/select.zig"),
            .append => @import("modes/append.zig"),
            .move => @import("modes/move.zig"),
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
    fn gen(m: Mode, vertices: *geometry.Vertices, indices: *geometry.Indices) !void {
        switch (m) {
            inline else => |cm| try cm.namespace().gen(vertices, indices),
        }
    }
    fn onEvent(m: Mode, event: platform.Event) !void {
        switch (m) {
            inline else => |cm| try cm.namespace().onEvent(event),
        }
    }
};

pub var paths: std.ArrayList(DynamicPath) = undefined;
pub var selected_nodes: std.ArrayList(Node) = undefined;
pub var mode: Mode = .select;

pub fn init(allocator: std.mem.Allocator) void {
    paths = std.ArrayList(DynamicPath).init(allocator);
    selected_nodes = std.ArrayList(Node).init(allocator);
    history.init(allocator);
}

pub fn deinit() void {
    for (paths.items) |*path| path.deinit();
    paths.deinit();
    selected_nodes.deinit();
    history.deinit();
}

pub fn update() !void {
    root.vertices.clearRetainingCapacity();
    root.indices.clearRetainingCapacity();
    try mode.gen(&root.vertices, &root.indices);
    root.tool_buffer.write(root.vertices.items, root.indices.items);
}

fn updatePaths() !void {
    root.vertices.clearRetainingCapacity();
    root.indices.clearRetainingCapacity();
    for (paths.items) |*path|
        try path.toPath().gen(&root.vertices, &root.indices);
    root.main_buffer.write(root.vertices.items, root.indices.items);
}

pub fn step() !void {
    try history.step();
    try updatePaths();
}

pub fn onEvent(event: platform.Event) !void {
    switch (event) {
        .key_press => |key| switch (key) {
            .z, .y => {
                if (input.isPressed(.left_ctrl) or input.isPressed(.right_ctrl)) {
                    selected_nodes.clearRetainingCapacity();
                    _ = try setMode(.select);
                    if (key == .z) try history.undo() else try history.redo();
                    try updatePaths();
                }
            },
            .a => _ = try setMode(.append),
            .g => _ = try setMode(.move),
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
        if (selected_node.path_index == node.path_index and selected_node.index == node.index)
            return @intCast(u32, node_index);
    }
    return null;
}

pub inline fn isSelected(node: Node) bool {
    return findSelected(node) != null;
}
