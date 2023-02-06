const std = @import("std");
const math = @import("math");
const render = @import("render");

const Image = @import("Image.zig");
const ImageSelection = @import("ImageSelection.zig");
const History = @import("History.zig");
const snapping = @import("snapping.zig");

pub var history: History = undefined;
pub var operation: ?Operation = null;
pub var capture: ?Capture = null;
pub var operation_in_new = false;

const live_preview = true;
pub var should_draw_canvas = true;
pub var should_draw_image = true;
pub var should_draw_helper = true;
pub var should_update_transform = true;

pub var window_size: math.Vec2 = .{ 0, 0 };
pub var canvas_pan: math.Vec2 = .{ 0, 0 };
pub var canvas_zoom: f32 = 1;
const canvas_size = math.Vec2{ 512, 512 };
const canvas_corner_radius: f32 = 16;

const default_style = Image.PathStyle{
    .stroke = .{ .width = 2, .cap = .round },
    .fill_color = .{ 0.5, 0.5, 0.5, 1 },
    .stroke_color = .{ 0, 0, 0, 1 },
};

pub const Operation = union(enum) {
    Rename: Rename,
    ChangeStyle: ChangeStyle,
    AddPoint: AddPoint,
    Append: Append,
    Connect: Connect,
    Move: Move,
    Remove: Remove,
    ChangeAngle: ChangeAngle,

    pub fn apply(op: Operation, sel: ImageSelection) !ImageSelection {
        return switch (op) {
            inline else => |comptime_op| comptime_op.apply(sel),
        };
    }

    pub fn generateHelper(op: Operation, sel: ImageSelection, gen: anytype) !void {
        return switch (op) {
            inline else => |comptime_op| if (@hasDecl(@TypeOf(comptime_op), "generateHelper")) comptime_op.generateHelper(sel, gen),
        };
    }

    pub const Rename = struct {
        name: [16]u8,

        pub fn init(sel: ImageSelection) ?Rename {
            if (sel.loops.items.len == 1 and sel.intervals.len == 0)
                return .{ .name = sel.image.pathName(sel.loops.items[0]) };
            if (sel.loops.items.len == 0 and sel.intervals.len == 1) {
                const index = sel.intervals.items(.index)[0];
                const interval = sel.intervals.items(.interval)[0];
                if (interval.a == 0 and interval.b == sel.image.pathLen(index) - 1)
                    return .{ .name = sel.image.pathName(index) };
            }
            return null;
        }

        pub fn apply(op: Rename, sel: ImageSelection) !ImageSelection {
            const index = if (sel.loops.items.len > 0) sel.loops.items[0] else sel.intervals.items(.index)[0];
            var out = try sel.clone();
            out.image.entries.items(.name)[index] = op.name;
            return out;
        }
    };

    pub const ChangeStyle = struct {
        style: Image.PathStyle,

        pub fn init(sel: ImageSelection) ?ChangeStyle {
            if (sel.loops.items.len == 1 and sel.intervals.len == 0)
                return .{ .style = sel.image.pathStyle(sel.loops.items[0]) };
            if (sel.loops.items.len == 0 and sel.intervals.len == 1) {
                const index = sel.intervals.items(.index)[0];
                const interval = sel.intervals.items(.interval)[0];
                if (interval.a == 0 and interval.b == sel.image.pathLen(index) - 1)
                    return .{ .style = sel.image.pathStyle(index) };
            }
            return null;
        }

        pub fn apply(op: ChangeStyle, sel: ImageSelection) !ImageSelection {
            const index = if (sel.loops.items.len > 0) sel.loops.items[0] else sel.intervals.items(.index)[0];
            var out = try sel.clone();
            out.image.entries.items(.style)[index] = op.style;
            return out;
        }
    };

    pub const AddPoint = struct {
        position: math.Vec2 = .{ 0, 0 },
        style: Image.PathStyle = default_style,
        name: Image.PathName = .{ 'u', 'n', 'n', 'a', 'm', 'e', 'd' } ++ .{0} ** 9,

        pub fn init(sel: ImageSelection) ?AddPoint {
            if (!sel.isNothingSelected()) return null;
            return .{};
        }

        pub fn apply(op: AddPoint, sel: ImageSelection) !ImageSelection {
            var out = try sel.cloneWithNothingSelected();
            try out.image.addPoint(op.position, op.style, op.name);
            try out.selectNode(@intCast(u32, sel.image.entries.len), 0);
            return out;
        }

        pub fn generateHelper(op: AddPoint, _: ImageSelection, gen: anytype) !void {
            var pass = getWideStroke().generator(gen).begin();
            try pass.end(op.position, null);
        }
    };

    pub const Append = struct {
        position: math.Vec2,
        angle: f32 = 0,
        _pos_a: math.Vec2,

        pub fn init(sel: ImageSelection) ?Append {
            if (!(sel.loops.items.len == 0 and sel.intervals.len == 1)) return null;
            const index = sel.intervals.items(.index)[0];
            const path = sel.image.getPath(index);
            const interval = sel.intervals.items(.interval)[0];
            if (!interval.isLooseEnd(path)) return null;
            const pos_a = sel.image.getPath(index).positions[interval.a];
            return .{ ._pos_a = pos_a, .position = pos_a };
        }

        pub fn apply(op: Append, sel: ImageSelection) !ImageSelection {
            const index = sel.intervals.items(.index)[0];
            const interval = sel.intervals.items(.interval)[0];

            var out = try sel.cloneWithNothingSelected();
            if (interval.a == 0)
                out.image.reversePath(index);
            if (snapping.snapToLooseEnd(sel.image, op.position, getSnapDist())) |res| {
                if (res.index == index) {
                    if (res.node != interval.a)
                        out.image.loopPath(index, op.angle);
                } else {
                    if (res.node != 0)
                        out.image.reversePath(res.index);
                    _ = out.image.joinPaths(index, res.index, op.angle);
                }
            } else {
                try out.image.appendPoint(index, op.position, op.angle);
                try out.selectNode(index, out.image.pathLen(index) - 1);
            }
            return out;
        }

        pub fn generateHelper(op: Append, sel: ImageSelection, gen: anytype) !void {
            const index = sel.intervals.items(.index)[0];
            const interval = sel.intervals.items(.interval)[0];

            try math.Arc.generate(.{
                .pos_a = sel.image.getPath(index).positions[interval.a],
                .pos_b = if (snapping.snapToLooseEnd(sel.image, op.position, getSnapDist())) |res| sel.image.getPositions(res.index)[res.node] else op.position,
                .angle = op.angle,
            }, getStroke().generator(gen));
        }
    };

    pub const Connect = struct {
        angle: f32 = 0,
        _pos_a: math.Vec2,
        _pos_b: math.Vec2,

        pub fn init(sel: ImageSelection) ?Connect {
            if (!(sel.loops.items.len == 0 and sel.intervals.len == 2)) return null;
            const path_a = sel.image.getPath(sel.intervals.items(.index)[0]);
            const path_b = sel.image.getPath(sel.intervals.items(.index)[1]);
            const interval_a = sel.intervals.items(.interval)[0];
            const interval_b = sel.intervals.items(.interval)[1];
            if (!interval_a.isLooseEnd(path_a) or !interval_b.isLooseEnd(path_b)) return null;
            return .{ ._pos_a = path_a.positions[interval_a.a], ._pos_b = path_b.positions[interval_b.a] };
        }

        pub fn apply(op: Connect, sel: ImageSelection) !ImageSelection {
            var index_a = sel.intervals.items(.index)[0];
            var index_b = sel.intervals.items(.index)[1];
            var interval_a = sel.intervals.items(.interval)[0];
            var interval_b = sel.intervals.items(.interval)[1];

            var out = try sel.cloneWithNothingSelected();
            if (interval_a.a == 0) out.image.reversePath(index_a);
            if (interval_b.a != 0) out.image.reversePath(index_b);
            const node = out.image.pathLen(index_a) - 1;
            const index = out.image.joinPaths(index_a, index_b, op.angle);
            try out.selectSegment(index, node);
            return out;
        }
    };

    pub const Move = struct {
        offset: math.Vec2 = .{ 0, 0 },

        pub fn init(sel: ImageSelection) ?Move {
            if (sel.isNothingSelected()) return null;
            return .{};
        }

        fn getMat(op: Move) math.Mat3 {
            return math.mat3.translate(op.offset);
        }

        pub fn apply(op: Move, sel: ImageSelection) !ImageSelection {
            var out = try sel.clone();
            out.transformSelected(op.getMat());
            return out;
        }

        pub fn generateHelper(op: Move, sel: ImageSelection, gen: anytype) !void {
            try sel.generateSelected(math.transformGenerator(op.getMat(), getWideStroke().generator(gen)));
            try sel.generateTransformEdges(op.getMat(), getStroke().generator(gen));
        }
    };

    pub const Remove = struct {
        remove_single_nodes: bool = true,

        pub fn init(sel: ImageSelection) ?Remove {
            if (sel.isNothingSelected()) return null;
            return .{};
        }

        pub fn apply(op: Remove, sel: ImageSelection) !ImageSelection {
            var out = ImageSelection.init(sel.image.allocator);
            var it = sel.image.pathIterator();
            while (it.next()) |path| {
                if (path.isLooped()) {
                    try op.addUnselectedLoop(&out.image, sel, it.getIndex());
                } else {
                    try op.addUnselectedInterval(&out.image, sel, it.getIndex(), .{ .a = 0, .b = path.len() - 1 });
                }
            }
            return out;
        }

        fn addUnselectedLoop(op: Remove, out_drawing: *Image, sel: ImageSelection, index: u32) !void {
            for (sel.loops.items) |sel_index| {
                if (sel_index == index)
                    return;
            }
            for (sel.intervals.items(.index)) |sel_index, i| {
                if (sel_index == index) {
                    const sel_interval = sel.intervals.items(.interval)[i];
                    if (!sel_interval.isSingleNode()) {
                        try op.addUnselectedInterval(out_drawing, sel, index, .{ .a = sel_interval.b, .b = sel_interval.a });
                        return;
                    }
                    if (sel_interval.isSingleNode() and op.remove_single_nodes) {
                        try op.addUnselectedInterval(out_drawing, sel, index, .{ .a = sel.image.pathNextNode(index, sel_interval.b), .b = sel.image.pathPrevNode(index, sel_interval.a) });
                        return;
                    }
                }
            }
            const path = sel.image.getPath(index);
            try out_drawing.addPoint(path.positions[0], sel.image.pathStyle(index), sel.image.pathName(index));
            const new_index = @intCast(u32, out_drawing.entries.len - 1);
            var i: u32 = 0;
            while (i + 1 < path.len()) : (i += 1)
                try out_drawing.appendPoint(new_index, path.positions[i + 1], path.angles[i]);
            out_drawing.loopPath(new_index, path.angles[i]);
        }

        fn addUnselectedInterval(op: Remove, out_drawing: *Image, sel: ImageSelection, index: u32, interval: ImageSelection.Interval) !void {
            for (sel.intervals.items(.index)) |sel_index, i| {
                if (sel_index == index) {
                    const sel_interval = sel.intervals.items(.interval)[i];
                    if (!sel_interval.isSingleNode() and interval.containsSegment(sel_interval.a)) {
                        if (sel_interval.a != interval.a)
                            try op.addUnselectedInterval(out_drawing, sel, index, .{ .a = interval.a, .b = sel_interval.a });
                        if (sel_interval.b != interval.b)
                            try op.addUnselectedInterval(out_drawing, sel, index, .{ .a = sel_interval.b, .b = interval.b });
                        return;
                    }
                    if (sel_interval.isSingleNode() and op.remove_single_nodes and interval.containsNode(sel_interval.a)) {
                        if (sel_interval.a != interval.a)
                            try op.addUnselectedInterval(out_drawing, sel, index, .{ .a = interval.a, .b = sel.image.pathPrevNode(index, sel_interval.a) });
                        if (sel_interval.b != interval.b)
                            try op.addUnselectedInterval(out_drawing, sel, index, .{ .a = sel.image.pathNextNode(index, sel_interval.b), .b = interval.b });
                        return;
                    }
                    if (interval.isSingleNode() and sel_interval.containsNode(interval.a))
                        return;
                }
            }
            const path = sel.image.getPath(index);
            try out_drawing.addPoint(path.positions[interval.a], sel.image.pathStyle(index), sel.image.pathName(index));
            const new_index = @intCast(u32, out_drawing.entries.len - 1);
            var i = interval.a;
            while (i != interval.b) : (i = path.nextNode(i))
                try out_drawing.appendPoint(new_index, path.positions[path.nextNode(i)], path.angles[i]);
        }
    };

    pub const ChangeAngle = struct {
        angle: f32,
        _pos_a: math.Vec2, // helpers
        _pos_b: math.Vec2,

        pub fn init(sel: ImageSelection) ?ChangeAngle {
            if (!(sel.loops.items.len == 0 and sel.intervals.len == 1)) return null;
            const path = sel.image.getPath(sel.intervals.items(.index)[0]);
            const interval = sel.intervals.items(.interval)[0];
            if (!interval.isSingleSegment(path)) return null;
            const arc = path.getArc(interval.a);
            return .{ .angle = arc.angle, ._pos_a = arc.pos_a, ._pos_b = arc.pos_b };
        }

        pub fn apply(op: ChangeAngle, sel: ImageSelection) !ImageSelection {
            var out = try sel.clone();
            const interval = sel.intervals.items(.interval)[0];
            out.image.getAngles(sel.intervals.items(.index)[0])[interval.a] = op.angle;
            return out;
        }

        pub fn generateHelper(op: ChangeAngle, sel: ImageSelection, gen: anytype) !void {
            const path = sel.image.getPath(sel.intervals.items(.index)[0]);
            const interval = sel.intervals.items(.interval)[0];
            var arc = path.getArc(interval.a);
            arc.angle = op.angle;
            try arc.generate(getStroke().generator(gen));
        }
    };
};

pub const Capture = union(enum) {
    Position: Position,
    Offset: Offset,
    Angle: Angle,

    pub fn cancel(any_capture: Capture) void {
        return switch (any_capture) {
            inline else => |comptime_capture| comptime_capture.cancel(),
        };
    }

    pub const Position = struct {
        pos: *math.Vec2,
        orig_pos: math.Vec2,

        pub fn init(pos: *math.Vec2) Position {
            return .{ .pos = pos, .orig_pos = pos.* };
        }

        pub fn cancel(cap: Position) void {
            cap.pos.* = cap.orig_pos;
        }
    };

    pub const Offset = struct {
        offset: *math.Vec2,
        orig_offset: math.Vec2,

        pub fn init(offset: *math.Vec2) Offset {
            return .{ .offset = offset, .orig_offset = offset.* };
        }

        pub fn cancel(cap: Offset) void {
            cap.offset.* = cap.orig_offset;
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

        pub fn cancel(cap: Angle) void {
            cap.angle.* = cap.orig_angle;
        }
    };
};

pub fn init(allocator: std.mem.Allocator) !void {
    history = History.init(allocator);
    try history.add(ImageSelection.init(allocator));
}

pub fn deinit() void {
    history.deinit();
}

fn applyOperation() !void {
    if (operation) |op| {
        if (!history.undo()) unreachable;
        try history.add(try op.apply(history.get().*));
        should_draw_helper = true;
        should_draw_image = true;
    }
}

pub fn updateOperation() !void {
    if (capture == null or live_preview)
        try applyOperation();
    should_draw_helper = true;
}

pub fn finishOperation() !void {
    if (capture != null and !live_preview)
        try applyOperation();
    operation = null;
    capture = null;
    should_draw_helper = true;
}

pub fn setOperation(new_operation: Operation) !void {
    try finishOperation();
    operation = new_operation;
    operation_in_new = true;
    try history.add(try history.get().clone());
    try updateOperation();
}

const select_color = [4]f32{ 0.9, 0.9, 0, 1 };
const preview_color = [4]f32{ 0.9, 0, 0, 1 };

pub fn drawImage(buffer: *render.Buffer) !void {
    try history.get().image.draw(buffer);
}

pub fn drawHelper(buffer: *render.Buffer) !void {
    if (capture != null) {
        try operation.?.generateHelper(history.getPrev().*, buffer.generator(preview_color));
    } else {
        try history.get().generateSelected(getWideStroke().generator(buffer.generator(select_color)));
    }
}

pub fn drawCanvas(buffer: *render.Buffer) !void {
    const rect = math.RoundedRect{
        .pos = .{ 0, 0 },
        .radius = canvas_size / math.vec2.splat(2),
        .corner_radius = canvas_corner_radius,
    };
    try rect.generate(buffer.generator(.{ 255, 255, 255, 255 }));
}

pub fn getTransform() math.Mat3 {
    const scale = math.vec2.splat(2 / canvas_zoom) / window_size;
    return math.mat3.mult(math.mat3.scale(.{ scale[0], scale[1], 1 }), math.mat3.translate(-canvas_pan));
}

pub fn getSnapDist() f32 {
    return 10 * canvas_zoom;
}

fn getStroke() math.Stroke {
    return .{ .width = 2 * canvas_zoom, .cap = .round };
}
fn getWideStroke() math.Stroke {
    return .{ .width = 4 * canvas_zoom, .cap = .round };
}
