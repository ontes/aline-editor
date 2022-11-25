const std = @import("std");
const render = @import("../render.zig");
const geometry = @import("../geometry.zig");
const platform = @import("../platform.zig");
const editor = @import("../editor.zig");

const Entry = @import("History.zig").Entry;
const Drawing = @import("Drawing.zig");
const Selection = @import("Selection.zig");
const properties = @import("properties.zig");
const snapping = @import("snapping.zig");

const basic_stroke = geometry.Stroke{ .width = 0.005, .cap = .round };
const wide_stroke = geometry.Stroke{ .width = 0.01, .cap = .round };
const helper_color = [4]u8{ 255, 64, 64, 255 };

const default_style = Drawing.Style{
    .stroke = .{ .width = 0.005, .cap = .round },
    .fill_color = .{ 64, 64, 64, 255 },
    .stroke_color = .{ 255, 255, 255, 255 },
};

pub const AnyOperation = union(enum) {
    AddPoint: AddPoint,
    Append: Append,
    Connect: Connect,
    Move: Move,
    Delete: Delete,
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

    pub fn apply(op: AnyOperation, entry: Entry) !Entry {
        return switch (op) {
            inline else => |comptime_op| comptime_op.apply(entry),
        };
    }

    pub fn drawHelper(op: AnyOperation, entry: Entry, buffer: *render.Buffer) !void {
        return switch (op) {
            inline else => |comptime_op| comptime_op.drawHelper(entry, buffer),
        };
    }
};

pub const AddPoint = struct {
    position: properties.Position,
    style: Drawing.Style = default_style,

    pub fn init(entry: Entry) ?AddPoint {
        if (!entry.selection.isEmpty()) return null;

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

    pub fn apply(op: AddPoint, entry: Entry) !Entry {
        var out = try entry.cloneDrawingOnly();
        try out.drawing.addPoint(op.position.val, op.style);
        try out.selection.selectNode(@intCast(u32, entry.drawing.entries.len), 0);
        return out;
    }

    pub fn drawHelper(op: AddPoint, _: Entry, buffer: *render.Buffer) !void {
        try wide_stroke.drawPoint(op.position.val, helper_color, buffer);
    }
};

pub const Append = struct {
    position: properties.Position,
    angle: f32 = 0,

    pub fn init(entry: Entry) ?Append {
        if (!(entry.selection.loops.items.len == 0 and entry.selection.intervals.len == 1)) return null;
        const index = entry.selection.intervals.items(.index)[0];
        const path = entry.drawing.getPath(index);
        const interval = entry.selection.intervals.items(.interval)[0];
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

    pub fn apply(op: Append, entry: Entry) !Entry {
        const index = entry.selection.intervals.items(.index)[0];
        const interval = entry.selection.intervals.items(.interval)[0];

        var out = try entry.cloneDrawingOnly();
        if (interval.a == 0)
            out.drawing.reversePath(index);

        var it = out.drawing.pathIterator();
        while (it.next()) |path| {
            const node = snapping.closestLooseEnd(path, op.position.val);
            if (snapping.distToPoint(path.positions[node], op.position.val) < snapping.snap_dist) {
                if (it.getIndex() == index and node != interval.a) {
                    out.drawing.loopPath(index, op.angle);
                    break;
                }
                if (it.getIndex() != index) {
                    if (node != 0) out.drawing.reversePath(it.getIndex());
                    out.drawing.joinPaths(index, it.getIndex(), op.angle);
                    break;
                }
            }
        } else {
            try out.drawing.appendPoint(index, op.position.val, op.angle);
            try out.selection.selectNode(index, out.drawing.getLen(index) - 1);
        }
        return out;
    }

    pub fn drawHelper(op: Append, entry: Entry, buffer: *render.Buffer) !void {
        const index = entry.selection.intervals.items(.index)[0];
        const interval = entry.selection.intervals.items(.interval)[0];
        const pos_a = entry.drawing.getPath(index).positions[interval.a];
        var pos_b = op.position.val;
        var it = entry.drawing.pathIterator();
        while (it.next()) |path| {
            const node = snapping.closestLooseEnd(path, op.position.val);
            if (snapping.distToPoint(path.positions[node], op.position.val) < snapping.snap_dist) {
                if (it.getIndex() != index or node != interval.a) {
                    pos_b = path.positions[node];
                    break;
                }
            }
        }
        try basic_stroke.drawArc(.{ .pos_a = pos_a, .pos_b = pos_b }, helper_color, buffer);
    }
};

pub const Connect = struct {
    angle: f32 = 0,

    pub fn init(entry: Entry) ?Connect {
        if (!(entry.selection.loops.items.len == 0 and entry.selection.intervals.len == 2)) return null;
        if (!entry.selection.intervals.items(.interval)[0].isLooseEnd(entry.drawing.getPath(entry.selection.intervals.items(.index)[0]))) return null;
        if (!entry.selection.intervals.items(.interval)[1].isLooseEnd(entry.drawing.getPath(entry.selection.intervals.items(.index)[1]))) return null;
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

    pub fn apply(op: Connect, entry: Entry) !Entry {
        var index0 = entry.selection.intervals.items(.index)[0];
        var index1 = entry.selection.intervals.items(.index)[1];
        var interval0 = entry.selection.intervals.items(.interval)[0];
        var interval1 = entry.selection.intervals.items(.interval)[1];

        var out = try entry.cloneDrawingOnly();
        if (index0 == index1) {
            out.drawing.loopPath(index0, op.angle);
            try out.selection.selectSegment(index0, out.drawing.getLen(index0) - 1, out.drawing);
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
            try out.selection.selectSegment(index0, join_index, out.drawing);
        }
        return out;
    }

    pub fn drawHelper(op: Connect, entry: Entry, buffer: *render.Buffer) !void {
        _ = op;
        _ = entry;
        _ = buffer;
        // TODO
    }
};

pub const Move = struct {
    offset: properties.Offset,

    pub fn init(entry: Entry) ?Move {
        if (entry.selection.isEmpty()) return null;

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

    fn transform(pos: geometry.Vec2, offset: geometry.Vec2) geometry.Vec2 {
        return pos + offset;
    }

    pub fn apply(op: Move, entry: Entry) !Entry {
        std.debug.print("Move.\n", .{});
        var out = try entry.clone();
        entry.selection.apply(&out.drawing, op.offset.val, transform);
        return out;
    }

    pub fn drawHelper(op: Move, entry: Entry, buffer: *render.Buffer) !void {
        try entry.selection.drawApply(entry.drawing, op.offset.val, transform, wide_stroke, helper_color, buffer);
        try entry.selection.drawApplyEdges(entry.drawing, op.offset.val, transform, basic_stroke, helper_color, buffer);
    }
};

pub const Delete = struct {
    pub fn init(entry: Entry) ?Delete {
        if (entry.selection.isEmpty()) return null;
        return .{};
    }

    pub fn isGrabbed(_: Delete) bool {
        return false; // TODO
    }

    pub fn onEvent(_: *Delete, event: platform.Event) !void {
        _ = event;
        // TODO
    }

    pub fn apply(_: Delete, entry: Entry) !Entry {
        var out = Entry.init(entry.drawing.allocator);
        var it = entry.drawing.pathIterator();
        while (it.next()) |path| {
            if (path.isLooped()) {
                try addUnselectedLoop(&out.drawing, entry, it.getIndex());
            } else {
                try addUnselectedInterval(&out.drawing, entry, it.getIndex(), .{ .a = 0, .b = path.len() - 1 });
            }
        }
        return out;
    }

    fn addUnselectedLoop(out_drawing: *Drawing, entry: Entry, index: u32) !void {
        for (entry.selection.loops.items) |sel_index| {
            if (sel_index == index)
                return;
        }
        for (entry.selection.intervals.items(.index)) |sel_index, i| {
            if (sel_index == index) {
                const sel_interval = entry.selection.intervals.items(.interval)[i];
                if (!sel_interval.isSingleNode()) {
                    try addUnselectedInterval(out_drawing, entry, index, .{ .a = sel_interval.b, .b = sel_interval.a });
                    return;
                }
            }
        }
        const path = entry.drawing.getPath(index);
        try out_drawing.addPoint(path.positions[0], entry.drawing.entries.items(.style)[index]);
        const new_index = @intCast(u32, out_drawing.entries.len - 1);
        var i: u32 = 0;
        while (i + 1 < path.len()) : (i += 1)
            try out_drawing.appendPoint(new_index, path.positions[i + 1], path.angles[i]);
        out_drawing.loopPath(new_index, path.angles[i]);
    }

    fn addUnselectedInterval(out_drawing: *Drawing, entry: Entry, index: u32, interval: Selection.Interval) !void {
        for (entry.selection.intervals.items(.index)) |sel_index, i| {
            if (sel_index == index) {
                const sel_interval = entry.selection.intervals.items(.interval)[i];
                if (!sel_interval.isSingleNode() and interval.containsSegment(sel_interval.a)) {
                    if (sel_interval.a != interval.a)
                        try addUnselectedInterval(out_drawing, entry, index, .{ .a = interval.a, .b = sel_interval.a });
                    if (sel_interval.b != interval.b)
                        try addUnselectedInterval(out_drawing, entry, index, .{ .a = sel_interval.b, .b = interval.b });
                    return;
                }
            }
        }
        const path = entry.drawing.getPath(index);
        try out_drawing.addPoint(path.positions[interval.a], entry.drawing.entries.items(.style)[index]);
        const new_index = @intCast(u32, out_drawing.entries.len - 1);
        var i = interval.a;
        while (i != interval.b) : (i = path.next(i))
            try out_drawing.appendPoint(new_index, path.positions[path.next(i)], path.angles[i]);
    }

    pub fn drawHelper(_: Delete, entry: Entry, buffer: *render.Buffer) !void {
        _ = entry;
        _ = buffer;
        // TODO
    }
};

pub const ChangeAngle = struct {
    angle: properties.Angle,

    pub fn init(entry: Entry) ?ChangeAngle {
        if (!(entry.selection.loops.items.len == 0 and entry.selection.intervals.len == 1)) return null;
        const path = entry.drawing.getPath(entry.selection.intervals.items(.index)[0]);
        const interval = entry.selection.intervals.items(.interval)[0];
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

    pub fn apply(op: ChangeAngle, entry: Entry) !Entry {
        var out = try entry.clone();
        const interval = entry.selection.intervals.items(.interval)[0];
        out.drawing.getAngles(entry.selection.intervals.items(.index)[0])[interval.a] = op.angle.val;
        return out;
    }

    pub fn drawHelper(op: ChangeAngle, entry: Entry, buffer: *render.Buffer) !void {
        const path = entry.drawing.getPath(entry.selection.intervals.items(.index)[0]);
        const interval = entry.selection.intervals.items(.interval)[0];
        var arc = path.getArc(interval.a);
        arc.angle = op.angle.val;
        try basic_stroke.drawArc(arc, helper_color, buffer);
    }
};
