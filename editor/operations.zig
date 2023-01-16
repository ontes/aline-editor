const std = @import("std");
const math = @import("math");
const platform = @import("platform");
const render = @import("render");

const editor = @import("editor.zig");
const Drawing = @import("Drawing.zig");
const Selection = @import("Selection.zig");
const properties = @import("properties.zig");
const snapping = @import("snapping.zig");
const input = @import("input.zig");

const default_style = Drawing.Style{
    .stroke = .{ .width = 2, .cap = .round },
    .fill_color = .{ 128, 255, 128, 255 },
    .stroke_color = .{ 0, 0, 0, 255 },
};

pub const AnyOperation = union(enum) {
    AddPoint: AddPoint,
    Append: Append,
    Connect: Connect,
    Move: Move,
    Remove: Remove,
    ChangeAngle: ChangeAngle,

    pub fn isGrabbed(op: AnyOperation) bool {
        return switch (op) {
            inline else => |comptime_op| comptime_op.isGrabbed(),
        };
    }

    pub fn onEvent(op: *AnyOperation, event: platform.Event) !void {
        return switch (op.*) {
            inline else => |*comptime_op| comptime_op.onEvent(event),
        };
    }

    pub fn apply(op: AnyOperation, sel: Selection) !Selection {
        return switch (op) {
            inline else => |comptime_op| comptime_op.apply(sel),
        };
    }

    pub fn generateHelper(op: AnyOperation, sel: Selection, gen: anytype) !void {
        return switch (op) {
            inline else => |comptime_op| comptime_op.generateHelper(sel, gen),
        };
    }
};

pub const AddPoint = struct {
    position: properties.Position,
    style: Drawing.Style = default_style,

    pub fn init(sel: Selection) ?AddPoint {
        if (!sel.isNothingSelected()) return null;

        var position_prop = properties.Position{ .val = .{ 0, 0 } };
        position_prop.beginGrab();
        return .{ .position = position_prop };
    }

    pub fn isGrabbed(op: AddPoint) bool {
        return op.position.isGrabbed();
    }

    pub fn onEvent(op: *AddPoint, event: platform.Event) !void {
        try op.position.onEvent(event);
    }

    pub fn apply(op: AddPoint, sel: Selection) !Selection {
        var out = try sel.cloneWithNothingSelected();
        try out.drawing.addPoint(op.position.val, op.style);
        try out.selectNode(@intCast(u32, sel.drawing.entries.len), 0);
        return out;
    }

    pub fn generateHelper(op: AddPoint, _: Selection, gen: anytype) !void {
        var pass = input.wideStroke().generator(gen).begin();
        try pass.end(op.position.val, null);
    }
};

pub const Append = struct {
    position: properties.Position,
    angle: f32 = 0,

    pub fn init(sel: Selection) ?Append {
        if (!(sel.loops.items.len == 0 and sel.intervals.len == 1)) return null;
        const index = sel.intervals.items(.index)[0];
        const path = sel.drawing.getPath(index);
        const interval = sel.intervals.items(.interval)[0];
        if (!interval.isLooseEnd(path)) return null;

        var position_prop = properties.Position{ .val = path.positions[interval.a] };
        position_prop.beginGrab();
        return .{ .position = position_prop };
    }

    pub fn isGrabbed(op: Append) bool {
        return op.position.isGrabbed();
    }

    pub fn onEvent(op: *Append, event: platform.Event) !void {
        try op.position.onEvent(event);
    }

    pub fn apply(op: Append, sel: Selection) !Selection {
        const index = sel.intervals.items(.index)[0];
        const interval = sel.intervals.items(.interval)[0];

        var out = try sel.cloneWithNothingSelected();
        if (interval.a == 0)
            out.drawing.reversePath(index);
        if (snapping.snapToLooseEnd(sel.drawing, op.position.val)) |res| {
            if (res.index == index) {
                if (res.node != interval.a)
                    out.drawing.loopPath(index, op.angle);
            } else {
                if (res.node != 0)
                    out.drawing.reversePath(res.index);
                out.drawing.joinPaths(index, res.index, op.angle);
            }
        } else {
            try out.drawing.appendPoint(index, op.position.val, op.angle);
            try out.selectNode(index, out.drawing.getLen(index) - 1);
        }
        return out;
    }

    pub fn generateHelper(op: Append, sel: Selection, gen: anytype) !void {
        const index = sel.intervals.items(.index)[0];
        const interval = sel.intervals.items(.interval)[0];

        try math.Arc.generate(.{
            .pos_a = sel.drawing.getPath(index).positions[interval.a],
            .pos_b = if (snapping.snapToLooseEnd(sel.drawing, op.position.val)) |res|
                sel.drawing.getPositions(res.index)[res.node]
            else
                op.position.val,
        }, input.standardStroke().generator(gen));
    }
};

pub const Connect = struct {
    angle: f32 = 0,

    pub fn init(sel: Selection) ?Connect {
        if (!(sel.loops.items.len == 0 and sel.intervals.len == 2)) return null;
        if (!sel.intervals.items(.interval)[0].isLooseEnd(sel.drawing.getPath(sel.intervals.items(.index)[0]))) return null;
        if (!sel.intervals.items(.interval)[1].isLooseEnd(sel.drawing.getPath(sel.intervals.items(.index)[1]))) return null;
        return .{};
    }

    pub fn isGrabbed(op: Connect) bool {
        _ = op;
        return false; // TODO
    }

    pub fn onEvent(op: *Connect, event: platform.Event) !void {
        _ = op;
        _ = event;
        // TODO
    }

    pub fn apply(op: Connect, sel: Selection) !Selection {
        var index0 = sel.intervals.items(.index)[0];
        var index1 = sel.intervals.items(.index)[1];
        var interval0 = sel.intervals.items(.interval)[0];
        var interval1 = sel.intervals.items(.interval)[1];

        var out = try sel.cloneWithNothingSelected();
        if (index0 == index1) {
            out.drawing.loopPath(index0, op.angle);
            try out.selectSegment(index0, out.drawing.getLen(index0) - 1);
        } else {
            if (index0 > index1) {
                std.mem.swap(u32, &index0, &index1);
                std.mem.swap(Selection.Interval, &interval0, &interval1);
            }
            if (interval0.a == 0)
                out.drawing.reversePath(index0);
            if (interval1.a != 0)
                out.drawing.reversePath(index1);

            const join_index = out.drawing.getLen(index0) - 1;
            out.drawing.joinPaths(index0, index1, op.angle);
            try out.selectSegment(index0, join_index);
        }
        return out;
    }

    pub fn generateHelper(op: Connect, sel: Selection, gen: anytype) !void {
        _ = op;
        _ = sel;
        _ = gen;
        // TODO
    }
};

pub const Move = struct {
    offset: properties.Offset,

    pub fn init(sel: Selection) ?Move {
        if (sel.isNothingSelected()) return null;

        var offset_prop = properties.Offset{};
        offset_prop.beginGrab();
        return .{ .offset = offset_prop };
    }

    pub fn isGrabbed(op: Move) bool {
        return op.offset.isGrabbed();
    }

    pub fn onEvent(op: *Move, event: platform.Event) !void {
        try op.offset.onEvent(event);
    }

    fn getMat(op: Move) math.Mat3 {
        return math.mat3.translate(op.offset.val);
    }

    pub fn apply(op: Move, sel: Selection) !Selection {
        var out = try sel.clone();
        out.transformSelected(op.getMat());
        return out;
    }

    pub fn generateHelper(op: Move, sel: Selection, gen: anytype) !void {
        try sel.generateSelected(math.transformGenerator(op.getMat(), input.wideStroke().generator(gen)));
        try sel.generateTransformEdges(op.getMat(), input.standardStroke().generator(gen));
    }
};

pub const Remove = struct {
    pub fn init(sel: Selection) ?Remove {
        if (sel.isNothingSelected()) return null;
        return .{};
    }

    pub fn isGrabbed(_: Remove) bool {
        return false; // TODO
    }

    pub fn onEvent(_: *Remove, event: platform.Event) !void {
        _ = event;
        // TODO
    }

    pub fn apply(_: Remove, sel: Selection) !Selection {
        var out = Selection.init(sel.drawing.allocator);
        var it = sel.drawing.pathIterator();
        while (it.next()) |path| {
            if (path.isLooped()) {
                try addUnselectedLoop(&out.drawing, sel, it.getIndex());
            } else {
                try addUnselectedInterval(&out.drawing, sel, it.getIndex(), .{ .a = 0, .b = path.len() - 1 });
            }
        }
        return out;
    }

    fn addUnselectedLoop(out_drawing: *Drawing, sel: Selection, index: u32) !void {
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
        const path = sel.drawing.getPath(index);
        try out_drawing.addPoint(path.positions[0], sel.drawing.entries.items(.style)[index]);
        const new_index = @intCast(u32, out_drawing.entries.len - 1);
        var i: u32 = 0;
        while (i + 1 < path.len()) : (i += 1)
            try out_drawing.appendPoint(new_index, path.positions[i + 1], path.angles[i]);
        out_drawing.loopPath(new_index, path.angles[i]);
    }

    fn addUnselectedInterval(out_drawing: *Drawing, sel: Selection, index: u32, interval: Selection.Interval) !void {
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
        const path = sel.drawing.getPath(index);
        try out_drawing.addPoint(path.positions[interval.a], sel.drawing.entries.items(.style)[index]);
        const new_index = @intCast(u32, out_drawing.entries.len - 1);
        var i = interval.a;
        while (i != interval.b) : (i = path.next(i))
            try out_drawing.appendPoint(new_index, path.positions[path.next(i)], path.angles[i]);
    }

    pub fn generateHelper(_: Remove, sel: Selection, gen: anytype) !void {
        _ = sel;
        _ = gen;
        // TODO
    }
};

pub const ChangeAngle = struct {
    angle: properties.Angle,

    pub fn init(sel: Selection) ?ChangeAngle {
        if (!(sel.loops.items.len == 0 and sel.intervals.len == 1)) return null;
        const path = sel.drawing.getPath(sel.intervals.items(.index)[0]);
        const interval = sel.intervals.items(.interval)[0];
        if (!interval.isSingleSegment(path)) return null;

        var angle_prop = properties.Angle{ .val = path.angles[interval.a] };
        angle_prop.beginGrab();
        return .{ .angle = angle_prop };
    }

    pub fn isGrabbed(op: ChangeAngle) bool {
        return op.angle.isGrabbed();
    }

    pub fn onEvent(op: *ChangeAngle, event: platform.Event) !void {
        try op.angle.onEvent(event);
    }

    pub fn apply(op: ChangeAngle, sel: Selection) !Selection {
        var out = try sel.clone();
        const interval = sel.intervals.items(.interval)[0];
        out.drawing.getAngles(sel.intervals.items(.index)[0])[interval.a] = op.angle.val;
        return out;
    }

    pub fn generateHelper(op: ChangeAngle, sel: Selection, gen: anytype) !void {
        const path = sel.drawing.getPath(sel.intervals.items(.index)[0]);
        const interval = sel.intervals.items(.interval)[0];
        var arc = path.getArc(interval.a);
        arc.angle = op.angle.val;
        try arc.generate(input.standardStroke().generator(gen));
    }
};
