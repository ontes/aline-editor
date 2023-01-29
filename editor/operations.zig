const std = @import("std");
const math = @import("math");

const Image = @import("Image.zig");
const ImageSelection = @import("ImageSelection.zig");
const snapping = @import("snapping.zig");
const canvas = @import("canvas.zig");

const default_properties = Image.PathProperties{
    .stroke = .{ .width = 2, .cap = .round },
    .fill_color = .{ 0.5, 0.5, 0.5, 1 },
    .stroke_color = .{ 0, 0, 0, 1 },
};

pub const AnyOperation = union(enum) {
    AddPoint: AddPoint,
    Append: Append,
    Connect: Connect,
    Move: Move,
    Remove: Remove,
    ChangeAngle: ChangeAngle,

    pub fn apply(op: AnyOperation, sel: ImageSelection) !ImageSelection {
        return switch (op) {
            inline else => |comptime_op| comptime_op.apply(sel),
        };
    }

    pub fn generateHelper(op: AnyOperation, sel: ImageSelection, gen: anytype) !void {
        return switch (op) {
            inline else => |comptime_op| comptime_op.generateHelper(sel, gen),
        };
    }
};

pub const AddPoint = struct {
    position: math.Vec2 = .{ 0, 0 },
    properties: Image.PathProperties = default_properties,

    pub fn init(sel: ImageSelection) ?AddPoint {
        if (!sel.isNothingSelected()) return null;
        return .{};
    }

    pub fn apply(op: AddPoint, sel: ImageSelection) !ImageSelection {
        var out = try sel.cloneWithNothingSelected();
        try out.image.addPoint(op.position, op.properties);
        try out.selectNode(@intCast(u32, sel.image.entries.len), 0);
        return out;
    }

    pub fn generateHelper(op: AddPoint, _: ImageSelection, gen: anytype) !void {
        var pass = canvas.wideStroke().generator(gen).begin();
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
        if (snapping.snapToLooseEnd(sel.image, op.position)) |res| {
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
            .pos_b = if (snapping.snapToLooseEnd(sel.image, op.position)) |res| sel.image.getPositions(res.index)[res.node] else op.position,
            .angle = op.angle,
        }, canvas.stroke().generator(gen));
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

    pub fn generateHelper(op: Connect, sel: ImageSelection, gen: anytype) !void {
        _ = op;
        _ = sel;
        _ = gen;
        // TODO
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
        try sel.generateSelected(math.transformGenerator(op.getMat(), canvas.wideStroke().generator(gen)));
        try sel.generateTransformEdges(op.getMat(), canvas.stroke().generator(gen));
    }
};

pub const Remove = struct {
    pub fn init(sel: ImageSelection) ?Remove {
        if (sel.isNothingSelected()) return null;
        return .{};
    }

    pub fn apply(_: Remove, sel: ImageSelection) !ImageSelection {
        var out = ImageSelection.init(sel.image.allocator);
        var it = sel.image.pathIterator();
        while (it.next()) |path| {
            if (path.isLooped()) {
                try addUnselectedLoop(&out.image, sel, it.getIndex());
            } else {
                try addUnselectedInterval(&out.image, sel, it.getIndex(), .{ .a = 0, .b = path.len() - 1 });
            }
        }
        return out;
    }

    fn addUnselectedLoop(out_drawing: *Image, sel: ImageSelection, index: u32) !void {
        for (sel.loops.items) |sel_index| {
            if (sel_index == index)
                return;
        }
        for (sel.intervals.items(.index)) |sel_index, i| {
            if (sel_index == index) {
                const sel_interval = sel.intervals.items(.interval)[i];
                if (!sel_interval.isSingleNode()) {
                    try addUnselectedInterval(out_drawing, sel, index, .{ .a = sel_interval.b, .b = sel_interval.a });
                    return;
                }
            }
        }
        const path = sel.image.getPath(index);
        try out_drawing.addPoint(path.positions[0], sel.image.entries.items(.properties)[index]);
        const new_index = @intCast(u32, out_drawing.entries.len - 1);
        var i: u32 = 0;
        while (i + 1 < path.len()) : (i += 1)
            try out_drawing.appendPoint(new_index, path.positions[i + 1], path.angles[i]);
        out_drawing.loopPath(new_index, path.angles[i]);
    }

    fn addUnselectedInterval(out_drawing: *Image, sel: ImageSelection, index: u32, interval: ImageSelection.Interval) !void {
        for (sel.intervals.items(.index)) |sel_index, i| {
            if (sel_index == index) {
                const sel_interval = sel.intervals.items(.interval)[i];
                if (!sel_interval.isSingleNode() and interval.containsSegment(sel_interval.a)) {
                    if (sel_interval.a != interval.a)
                        try addUnselectedInterval(out_drawing, sel, index, .{ .a = interval.a, .b = sel_interval.a });
                    if (sel_interval.b != interval.b)
                        try addUnselectedInterval(out_drawing, sel, index, .{ .a = sel_interval.b, .b = interval.b });
                    return;
                }
            }
        }
        const path = sel.image.getPath(index);
        try out_drawing.addPoint(path.positions[interval.a], sel.image.entries.items(.properties)[index]);
        const new_index = @intCast(u32, out_drawing.entries.len - 1);
        var i = interval.a;
        while (i != interval.b) : (i = path.nextNode(i))
            try out_drawing.appendPoint(new_index, path.positions[path.nextNode(i)], path.angles[i]);
    }

    pub fn generateHelper(_: Remove, sel: ImageSelection, gen: anytype) !void {
        _ = sel;
        _ = gen;
        // TODO
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
        try arc.generate(canvas.stroke().generator(gen));
    }
};
