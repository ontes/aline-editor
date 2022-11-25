const std = @import("std");
const render = @import("../render.zig");
const geometry = @import("../geometry.zig");
const Drawing = @import("Drawing.zig");

pub const Interval = struct {
    a: u32,
    b: u32,

    pub fn containsNode(interval: Interval, node: u32) bool {
        const a = node >= interval.a;
        const b = node <= interval.b;
        return if (interval.a <= interval.b) a and b else a or b;
    }
    pub fn containsSegment(interval: Interval, segment: u32) bool {
        const a = segment >= interval.a;
        const b = segment < interval.b;
        return if (interval.a <= interval.b) a and b else a or b;
    }

    pub fn isSingleNode(interval: Interval) bool {
        return interval.a == interval.b;
    }
    pub fn isSingleSegment(interval: Interval, path: geometry.Path) bool {
        return interval.a + 1 == interval.b or (path.isLooped() and path.next(interval.a) == interval.b);
    }
    pub fn isLooseEnd(interval: Interval, path: geometry.Path) bool {
        return interval.isSingleNode() and !path.isLooped() and
            (interval.a == 0 or interval.a == path.len() - 1);
    }
};

const Selection = @This();

allocator: std.mem.Allocator,
loops: std.ArrayListUnmanaged(u32) = .{},
intervals: std.MultiArrayList(struct { index: u32, interval: Interval }) = .{},

pub fn init(allocator: std.mem.Allocator) Selection {
    return .{ .allocator = allocator };
}

pub fn deinit(sel: *Selection) void {
    sel.loops.deinit(sel.allocator);
    sel.intervals.deinit(sel.allocator);
}

pub fn isEmpty(sel: Selection) bool {
    return sel.loops.items.len == 0 and sel.intervals.len == 0;
}

pub fn clear(sel: *Selection) void {
    sel.loops.clearRetainingCapacity();
    sel.intervals.shrinkRetainingCapacity(0);
}

pub fn isSelectedNode(sel: Selection, index: u32, node: u32) bool {
    for (sel.loops.items) |loop_index| {
        if (loop_index == index)
            return true;
    }
    for (sel.intervals.items(.index)) |interval_index, i| {
        if (interval_index == index and sel.intervals.items(.interval)[i].containsNode(node))
            return true;
    }
    return false;
}

pub fn isSelectedSegment(sel: Selection, index: u32, segment: u32) bool {
    for (sel.loops.items) |loop_index| {
        if (loop_index == index)
            return true;
    }
    for (sel.intervals.items(.index)) |interval_index, i| {
        if (interval_index == index and sel.intervals.items(.interval)[i].containsSegment(segment))
            return true;
    }
    return false;
}

fn addLoop(sel: *Selection, index: u32) !void {
    try sel.loops.append(sel.allocator, index);
}
fn addInterval(sel: *Selection, index: u32, interval: Interval) !void {
    try sel.intervals.append(sel.allocator, .{ .index = index, .interval = interval });
}

/// Selects node, assumes it isn't selected
pub fn selectNode(sel: *Selection, index: u32, node: u32) !void {
    try sel.addInterval(index, .{ .a = node, .b = node });
}

/// Selects segment, assumes it isn't selected
pub fn selectSegment(sel: *Selection, index: u32, segment: u32, drawing: Drawing) !void {
    const segment_end = drawing.getNext(index, segment);
    var a = segment;
    var b = segment_end;
    var i = sel.intervals.len;
    while (i > 0) : (i -= 1) {
        if (sel.intervals.items(.index)[i - 1] == index) {
            const sel_interval = sel.intervals.items(.interval)[i - 1];
            if (sel_interval.a == segment_end and sel_interval.b == segment) {
                _ = sel.intervals.swapRemove(i - 1);
                try sel.addLoop(index);
                return;
            }
            if (sel_interval.a == segment_end) {
                _ = sel.intervals.swapRemove(i - 1);
                b = sel_interval.b;
            }
            if (sel_interval.b == segment) {
                _ = sel.intervals.swapRemove(i - 1);
                a = sel_interval.a;
            }
        }
    }
    try sel.addInterval(index, .{ .a = a, .b = b });
}

/// Selects path, assumes no part of it is selected
pub fn selectPath(sel: *Selection, index: u32, drawing: Drawing) !void {
    if (drawing.getLooped(index)) {
        try sel.addLoop(index);
    } else {
        try sel.addInterval(index, .{ .a = 0, .b = drawing.getLen(index) - 1 });
    }
}

/// Deselects node. Returns true if node was selected prior to calling.
pub fn deselectNode(sel: *Selection, index: u32, node: u32, drawing: Drawing) !bool {
    for (sel.loops.items) |loop_index, i| {
        if (loop_index == index) {
            _ = sel.loops.swapRemove(i);
            try sel.addInterval(index, .{ .a = drawing.getNext(index, node), .b = drawing.getPrev(index, node) });
            return true;
        }
    }
    for (sel.intervals.items(.index)) |interval_index, i| {
        if (interval_index == index) {
            const interval = sel.intervals.items(.interval)[i];
            if (interval.containsNode(node)) {
                _ = sel.intervals.swapRemove(i);
                if (interval.a != node)
                    try sel.addInterval(index, .{ .a = interval.a, .b = drawing.getPrev(index, node) });
                if (interval.b != node)
                    try sel.addInterval(index, .{ .a = drawing.getNext(index, node), .b = interval.b });
                return true;
            }
        }
    }
    return false;
}

/// Deselects segment. Returns true if segment was selected prior to calling.
pub fn deselectSegment(sel: *Selection, index: u32, segment: u32, drawing: Drawing) !bool {
    const segment_end = drawing.getNext(index, segment);
    for (sel.loops.items) |loop_index, i| {
        if (loop_index == index) {
            _ = sel.loops.swapRemove(i);
            try sel.addInterval(index, .{ .a = segment_end, .b = segment });
            return true;
        }
    }
    for (sel.intervals.items(.index)) |interval_index, i| {
        if (interval_index == index) {
            const interval = sel.intervals.items(.interval)[i];
            if (interval.containsSegment(segment)) {
                _ = sel.intervals.swapRemove(i);
                if (interval.a != segment)
                    try sel.addInterval(index, .{ .a = interval.a, .b = segment });
                if (interval.b != segment_end)
                    try sel.addInterval(index, .{ .a = segment_end, .b = interval.b });
                return true;
            }
        }
    }
    return false;
}

/// Deselects path. Returns true if entire path was selected prior to calling.
pub fn deselectPath(sel: *Selection, index: u32, drawing: Drawing) !bool {
    for (sel.loops.items) |loop_index, i| {
        if (loop_index == index) {
            _ = sel.loops.swapRemove(i);
            return true;
        }
    }
    var i = sel.intervals.len;
    while (i > 0) : (i -= 1) {
        if (sel.intervals.items(.index)[i - 1] == index) {
            const interval = sel.intervals.items(.interval)[i - 1];
            _ = sel.intervals.swapRemove(i - 1);
            if (!drawing.getLooped(index) and interval.a == 0 and interval.b == drawing.getLen(index) - 1)
                return true;
        }
    }
    return false;
}

/// Selects node if not selected, deselects it otherwise.
pub fn toggleNode(sel: *Selection, index: u32, node: u32, drawing: Drawing) !void {
    if (!try sel.deselectNode(index, node, drawing))
        try sel.selectNode(index, node);
}

/// Selects segment if not selected, deselects it otherwise.
pub fn toggleSegment(sel: *Selection, index: u32, segment: u32, drawing: Drawing) !void {
    if (!try sel.deselectSegment(index, segment, drawing))
        try sel.selectSegment(index, segment, drawing);
}

/// Selects path if not selected, deselects it otherwise.
pub fn togglePath(sel: *Selection, index: u32, drawing: Drawing) !void {
    if (!try sel.deselectPath(index, drawing))
        try sel.selectPath(index, drawing);
}

pub fn selectAll(sel: *Selection, drawing: Drawing) !void {
    sel.clear();
    var index: u32 = 0;
    while (index < drawing.entries.len) : (index += 1)
        try sel.selectPath(index, drawing);
}

pub fn draw(sel: Selection, drawing: Drawing, stroke: geometry.Stroke, color: render.Color, buffer: *render.Buffer) !void {
    for (sel.loops.items) |index| {
        try stroke.drawPath(drawing.getPath(index), color, buffer);
    }
    for (sel.intervals.items(.index)) |index, j| {
        const interval = sel.intervals.items(.interval)[j];
        const path = drawing.getPath(index);
        var generator = stroke.begin(path.positions[interval.a], color, buffer);
        var i: u32 = interval.a;
        while (i != interval.b) : (i = path.next(i))
            try generator.add(path.angles[i], path.positions[path.next(i)]);
        try generator.finish();
    }
}

pub fn apply(
    sel: Selection,
    drawing: *Drawing,
    op_arg: anytype,
    op: fn (geometry.Vec2, @TypeOf(op_arg)) geometry.Vec2,
) void {
    for (sel.loops.items) |index| {
        for (drawing.getPositions(index)) |*position|
            position.* = op(position.*, op_arg);
    }
    for (sel.intervals.items(.index)) |index, i| {
        const interval = sel.intervals.items(.interval)[i];
        const positions = drawing.getPositions(index);
        var node = interval.a;
        while (node != interval.b) : (node = (node + 1) % @intCast(u32, positions.len))
            positions[node] = op(positions[node], op_arg);
        positions[node] = op(positions[node], op_arg);
    }
}

pub fn drawApply(
    sel: Selection,
    drawing: Drawing,
    op_arg: anytype,
    op: fn (geometry.Vec2, @TypeOf(op_arg)) geometry.Vec2,
    stroke: geometry.Stroke,
    color: render.Color,
    buffer: *render.Buffer,
) !void {
    for (sel.loops.items) |index| {
        const path = drawing.getPath(index);
        var generator = stroke.begin(op(path.positions[0], op_arg), color, buffer);
        var i: u32 = 0;
        while (i + 1 < path.len()) : (i += 1)
            try generator.add(path.angles[i], op(path.positions[i + 1], op_arg));
        try generator.finishLoop(path.angles[i]);
    }
    for (sel.intervals.items(.index)) |index, j| {
        const interval = sel.intervals.items(.interval)[j];
        const path = drawing.getPath(index);
        var generator = stroke.begin(op(path.positions[interval.a], op_arg), color, buffer);
        var i: u32 = interval.a;
        while (i != interval.b) : (i = path.next(i))
            try generator.add(path.angles[i], op(path.positions[path.next(i)], op_arg));
        try generator.finish();
    }
}

fn isSelected(sel: Selection, index: u32, node: u32) bool {
    for (sel.intervals.items(.index)) |interval_index, i|
        if (interval_index == index and sel.intervals.items(.interval)[i].containsNode(node))
            return true;
    return false;
}

pub fn drawApplyEdges(
    sel: Selection,
    drawing: Drawing,
    op_arg: anytype,
    op: fn (geometry.Vec2, @TypeOf(op_arg)) geometry.Vec2,
    stroke: geometry.Stroke,
    color: render.Color,
    buffer: *render.Buffer,
) !void {
    for (sel.intervals.items(.index)) |index, j| {
        const interval = sel.intervals.items(.interval)[j];
        const path = drawing.getPath(index);
        if ((path.isLooped() or interval.a > 0) and !sel.isSelected(index, path.prev(interval.a))) {
            var arc = path.getArc(path.prev(interval.a));
            arc.pos_b = op(arc.pos_b, op_arg);
            try stroke.drawArc(arc, color, buffer);
        }
        if (path.isLooped() or interval.b < path.len() - 1) {
            var arc = path.getArc(interval.b);
            arc.pos_a = op(arc.pos_a, op_arg);
            if (sel.isSelected(index, path.next(interval.b)))
                arc.pos_b = op(arc.pos_b, op_arg);
            try stroke.drawArc(arc, color, buffer);
        }
    }
}

pub fn clone(sel: *Selection) !Selection {
    return .{
        .allocator = sel.allocator,
        .loops = try sel.loops.clone(sel.allocator),
        .intervals = try sel.intervals.clone(sel.allocator),
    };
}
