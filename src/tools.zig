const std = @import("std");
const geometry = @import("geometry.zig");
const render = @import("render.zig");
const canvas = @import("canvas.zig");
const history = @import("history.zig");
const vec2 = @import("linalg.zig").vec(2, f32);

const preview_color = [4]u8{ 255, 32, 32, 255 };
const preview_stroke = geometry.Stroke{ .width = 0.005, .cap = .none };

const select_color = [4]u8{ 255, 255, 0, 255 };
const select_stroke = geometry.Stroke{ .width = 0.005, .cap = .none };

pub var tool_buffer: render.Buffer = undefined;

const Node = struct {
    object_index: u32,
    index: u32,

    pub inline fn getObject(node: Node) *canvas.Object {
        return &canvas.objects.items[node.object_index];
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
    pub inline fn pos(node: Node) geometry.Vec2 {
        return node.getPath().pos(node.index);
    }
    pub inline fn angleFrom(node: Node) ?f32 {
        return node.getPath().angleFrom(node.index);
    }
    pub inline fn angleTo(node: Node) ?f32 {
        return node.getPath().angleTo(node.index);
    }
    pub inline fn arcFrom(node: Node) ?geometry.Arc {
        return node.getPath().arcFrom(node.index);
    }
    pub inline fn arcTo(node: Node) ?geometry.Arc {
        return node.getPath().arcTo(node.index);
    }

    fn find(node: Node) ?u32 {
        for (nodes.items) |selected_node, node_index| {
            if (selected_node.object_index == node.object_index and selected_node.index == node.index)
                return @intCast(u32, node_index);
        }
        return null;
    }

    inline fn isSelected(node: Node) bool {
        return find(node) != null;
    }
};
var nodes: std.ArrayList(Node) = undefined;

const Tool = enum {
    select,
    append,
    move,
    change_angle,
    split,

    fn namespace(comptime md: Tool) type {
        return switch (md) {
            .select => select,
            .append => append,
            .move => move,
            .change_angle => change_angle,
            .split => split,
        };
    }

    fn canInit(m: Tool) bool {
        switch (m) {
            inline else => |cm| return cm.namespace().canInit(),
        }
    }
    fn init(m: Tool) !void {
        switch (m) {
            inline else => |cm| try cm.namespace().init(),
        }
    }
    fn deinit(m: Tool) void {
        switch (m) {
            inline else => |cm| cm.namespace().deinit(),
        }
    }
    fn gen(m: Tool, buffer: *render.Buffer) !void {
        switch (m) {
            inline else => |cm| try cm.namespace().gen(buffer),
        }
    }
    fn onMouseMove(m: Tool) !void {
        switch (m) {
            inline else => |cm| try cm.namespace().onMouseMove(),
        }
    }

    fn onMousePress(m: Tool) !void {
        switch (m) {
            inline else => |cm| try cm.namespace().onMousePress(),
        }
    }

    fn onMouseRelease(m: Tool) !void {
        switch (m) {
            inline else => |cm| try cm.namespace().onMouseRelease(),
        }
    }
};
var current_tool: Tool = .select;

pub fn setTool(tool: Tool) !bool {
    if (!tool.canInit())
        return false;
    current_tool.deinit();
    current_tool = tool;
    try current_tool.init();
    return true;
}

pub fn reset() void {
    nodes.clearRetainingCapacity();
    _ = setTool(.select) catch unreachable;
}

pub fn init(allocator: std.mem.Allocator, context: render.Context) void {
    nodes = std.ArrayList(Node).init(allocator);
    tool_buffer = render.Buffer.init(context, allocator);
}

pub fn deinit() void {
    nodes.deinit();
    tool_buffer.deinit();
}

pub var mouse_pos = [2]f32{ 0, 0 };
pub var shift_pressed = false;

pub fn onMouseMove(pos: [2]f32) !void {
    mouse_pos = pos;
    try current_tool.onMouseMove();
}

pub fn onMousePress() !void {
    try current_tool.onMousePress();
}

pub fn onMouseRelease() !void {
    try current_tool.onMouseRelease();
}

pub fn onShiftPress() void {
    shift_pressed = true;
}

pub fn onShiftRelease() void {
    shift_pressed = false;
}

const select = struct {
    pub inline fn canInit() bool {
        return true;
    }
    pub inline fn init() !void {
        try updateToolBuffer();
    }
    pub inline fn deinit() void {}

    fn updateToolBuffer() !void {
        tool_buffer.clear();
        for (nodes.items) |node| {
            try geometry.Circle.gen(.{ .pos = node.pos(), .radius = select_stroke.width * 2 }, select_color, &tool_buffer);
            if (node.next()) |next_node| if (next_node.isSelected())
                try select_stroke.genArc(node.arcFrom().?, select_color, &tool_buffer);
        }
        tool_buffer.flush();
    }

    fn onMouseMove() !void {}

    fn onMousePress() !void {
        if (!shift_pressed)
            nodes.clearRetainingCapacity();
        var i: u32 = 0;
        while (i < canvas.objects.items.len) : (i += 1) {
            const object_index = @intCast(u32, canvas.objects.items.len - i - 1);
            const path = canvas.objects.items[object_index].toPath();
            if (selectedNode(path, mouse_pos, 0.05)) |index| {
                const node = Node{ .object_index = object_index, .index = index };
                if (node.find()) |node_index| {
                    _ = nodes.swapRemove(node_index);
                } else {
                    try nodes.append(node);
                }
                break;
            }
            if (selectedArc(path, mouse_pos, 0.1)) |index| {
                const node = Node{ .object_index = object_index, .index = index };
                const next_node = node.next().?;
                var allready_selected = true;
                if (!node.isSelected()) {
                    allready_selected = false;
                    try nodes.append(node);
                }
                if (!next_node.isSelected()) {
                    allready_selected = false;
                    try nodes.append(next_node);
                }
                if (allready_selected) {
                    _ = nodes.swapRemove(node.find().?);
                    _ = nodes.swapRemove(next_node.find().?);
                }
                break;
            }
            if (path.isLooped() and path.containsPoint(mouse_pos)) {
                var allready_selected = true;
                var index: u32 = 0;
                while (index < path.len()) : (index += 1) {
                    const node = Node{ .object_index = object_index, .index = index };
                    if (!node.isSelected()) {
                        allready_selected = false;
                        try nodes.append(node);
                    }
                }
                if (allready_selected) {
                    index = 0;
                    while (index < path.len()) : (index += 1) {
                        const node = Node{ .object_index = object_index, .index = index };
                        _ = nodes.swapRemove(node.find().?);
                    }
                }
                break;
            }
        }
        try updateToolBuffer();
    }

    fn onMouseRelease() !void {}

    fn selectedNode(path: geometry.Path, pos: geometry.Vec2, max_diff: f32) ?u32 {
        var index: u32 = 0;
        while (index < path.len()) : (index += 1) {
            if (vec2.norm(pos - path.pos(index)) < max_diff * max_diff)
                return index;
        }
        return null;
    }

    fn selectedArc(path: geometry.Path, pos: geometry.Vec2, max_diff: f32) ?u32 {
        var index: u32 = 0;
        while (index < path.len()) : (index += 1) {
            if (path.arcFrom(index)) |arc| {
                if (@fabs(@tan(arc.angleOnPoint(pos) / 2) - @tan(arc.angle / 2)) < max_diff)
                    return index;
            }
        }
        return null;
    }
};

const move = struct {
    var start_pos: geometry.Vec2 = undefined;

    inline fn getOffset() geometry.Vec2 {
        return mouse_pos - start_pos;
    }

    pub fn canInit() bool {
        return nodes.items.len > 0;
    }

    pub fn init() !void {
        start_pos = mouse_pos;
        try updateToolBuffer();
    }

    pub fn deinit() void {
        start_pos = undefined;
    }

    fn updateToolBuffer() !void {
        tool_buffer.clear();
        for (nodes.items) |node| {
            if (node.prev()) |prev_node| {
                if (!prev_node.isSelected()) {
                    var arc = node.arcTo().?;
                    arc.pos_b = arc.pos_b + getOffset();
                    try preview_stroke.genArc(arc, preview_color, &tool_buffer);
                }
            }
            if (node.next()) |next_node| {
                var arc = node.arcFrom().?;
                arc.pos_a = arc.pos_a + getOffset();
                if (next_node.isSelected())
                    arc.pos_b = arc.pos_b + getOffset();
                try preview_stroke.genArc(arc, preview_color, &tool_buffer);
            }
        }
        tool_buffer.flush();
    }

    fn onMouseMove() !void {
        try updateToolBuffer();
    }

    fn onMousePress() !void {}

    fn onMouseRelease() !void {
        for (nodes.items) |node| {
            node.getObject().positions.items[node.index] = node.pos() + getOffset();
        }
        _ = try setTool(.select);
        try history.step();
    }
};

const append = struct {
    fn canInit() bool {
        return nodes.items.len == 0 or
            (nodes.items.len == 1 and (nodes.items[0].prev() == null or nodes.items[0].next() == null));
    }

    fn init() !void {
        if (nodes.items.len == 0) { // creating a new path
            try canvas.objects.append(try canvas.Object.init(canvas.objects.allocator, mouse_pos));
            try nodes.append(.{ .object_index = @intCast(u32, canvas.objects.items.len - 1), .index = 0 });
            try history.step();
        } else if (nodes.items[0].prev() == null) { // appending to beggining
            nodes.items[0].getObject().reverse();
            nodes.items[0].index = nodes.items[0].getPath().len() - 1;
        }
        try updateToolBuffer();
    }

    fn deinit() void {}

    fn updateToolBuffer() !void {
        tool_buffer.clear();
        try preview_stroke.genArc(.{ .pos_a = nodes.items[0].pos(), .pos_b = mouse_pos, .angle = 0 }, preview_color, &tool_buffer);
        tool_buffer.flush();
    }

    fn onMouseMove() !void {
        try updateToolBuffer();
    }

    fn onMousePress() !void {}

    fn onMouseRelease() !void {
        if (vec2.norm(mouse_pos - nodes.items[0].getPath().pos(0)) < 0.05 * 0.05) { // ending by creating a loop
            try nodes.items[0].getObject().loop(0);
            nodes.items[0].index = 0;
            _ = try setTool(.select);
        } else { // adding a new segment
            try nodes.items[0].getObject().append(mouse_pos, 0);
            nodes.items[0].index += 1;
        }
        try history.step();
    }
};

const change_angle = struct {
    inline fn getAngle() f32 {
        return nodes.items[0].arcFrom().?.angleOnPoint(mouse_pos);
    }

    fn canInit() bool {
        return nodes.items.len == 2 and nodes.items[0].object_index == nodes.items[1].object_index and
            ((if (nodes.items[0].next()) |next_node| next_node.index == nodes.items[1].index else false) or
            (if (nodes.items[0].prev()) |prev_node| prev_node.index == nodes.items[1].index else false));
    }

    fn init() !void {
        if (nodes.items[0].prev()) |prev_node| if (prev_node.index == nodes.items[1].index)
            std.mem.swap(Node, &nodes.items[0], &nodes.items[1]);
        try updateToolBuffer();
    }

    fn deinit() void {}

    fn updateToolBuffer() !void {
        tool_buffer.clear();
        var arc = nodes.items[0].arcFrom().?;
        arc.angle = getAngle();
        try preview_stroke.genArc(arc, preview_color, &tool_buffer);
        tool_buffer.flush();
    }

    fn onMouseMove() !void {
        try updateToolBuffer();
    }

    fn onMousePress() !void {}

    fn onMouseRelease() !void {
        nodes.items[0].getObject().angles.items[nodes.items[0].index] = getAngle();
        _ = try setTool(.select);
        try history.step();
    }
};

const split = struct {
    inline fn getParam() f32 {
        const arc = nodes.items[0].arcFrom().?;
        if (arc.angle == 0) {
            return geometry.linesIntersection(arc.pos_a, arc.pos_b - arc.pos_a, mouse_pos, geometry.normal(arc.pos_b - arc.pos_a));
        } else {
            const center = arc.toCircle().pos;
            return geometry.angleBetween(mouse_pos - center, arc.pos_a - center) / 2 / arc.angle;
        }
    }

    fn canInit() bool {
        return nodes.items.len == 2 and nodes.items[0].object_index == nodes.items[1].object_index and
            ((if (nodes.items[0].next()) |next_node| next_node.index == nodes.items[1].index else false) or
            (if (nodes.items[0].prev()) |prev_node| prev_node.index == nodes.items[1].index else false));
    }

    fn init() !void {
        if (nodes.items[0].prev()) |prev_node| if (prev_node.index == nodes.items[1].index)
            std.mem.swap(Node, &nodes.items[0], &nodes.items[1]);
        try updateToolBuffer();
    }

    fn deinit() void {}

    fn updateToolBuffer() !void {
        tool_buffer.clear();
        const pos = nodes.items[0].arcFrom().?.point(getParam());
        try geometry.Circle.gen(.{ .pos = pos, .radius = preview_stroke.width * 2 }, preview_color, &tool_buffer);
        tool_buffer.flush();
    }

    fn onMouseMove() !void {
        try updateToolBuffer();
    }

    fn onMousePress() !void {}

    fn onMouseRelease() !void {
        try nodes.items[0].getObject().split(nodes.items[0].index, getParam());
        _ = nodes.swapRemove(0);
        _ = try setTool(.select);
        try history.step();
    }
};
