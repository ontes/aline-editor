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

pub inline fn addLoop(sel: *Selection, index: u32) !void {
    try sel.loops.append(sel.allocator, index);
}
pub inline fn addInterval(sel: *Selection, index: u32, interval: Interval) !void {
    try sel.intervals.append(sel.allocator, .{ .index = index, .interval = interval });
}

pub fn toggleNode(sel: *Selection, index: u32, node: u32, path: geometry.Path) !void {
    for (sel.loops.items) |loop_index, i| {
        if (loop_index == index) {
            _ = sel.loops.swapRemove(i);
            try sel.addInterval(index, .{ .a = path.next(node), .b = path.prev(node) });
            return;
        }
    }
    for (sel.intervals.items(.index)) |interval_index, i| {
        if (interval_index == index) {
            const interval = sel.intervals.items(.interval)[i];
            if (interval.containsNode(node)) {
                _ = sel.intervals.swapRemove(i);
                if (interval.a != node)
                    try sel.addInterval(index, .{ .a = interval.a, .b = path.prev(node) });
                if (interval.b != node)
                    try sel.addInterval(index, .{ .a = path.next(node), .b = interval.b });
                return;
            }
        }
    }
    try sel.addInterval(index, .{ .a = node, .b = node });
}

pub fn toggleSegment(sel: *Selection, index: u32, segment: u32, path: geometry.Path) !void {
    for (sel.loops.items) |loop_index, i| {
        if (loop_index == index) {
            _ = sel.loops.swapRemove(i);
            try sel.addInterval(index, .{ .a = path.next(segment), .b = segment });
            return;
        }
    }
    var a = segment;
    var b = path.next(segment);
    var i = sel.intervals.len;
    while (i > 0) : (i -= 1) {
        if (sel.intervals.items(.index)[i - 1] == index) {
            const interval = sel.intervals.items(.interval)[i - 1];
            if (interval.containsSegment(segment)) {
                _ = sel.intervals.swapRemove(i - 1);
                if (interval.a != segment)
                    try sel.addInterval(index, .{ .a = interval.a, .b = segment });
                if (interval.b != path.next(segment))
                    try sel.addInterval(index, .{ .a = path.next(segment), .b = interval.b });
                return;
            }
            if (interval.a == path.next(segment) and interval.b == segment) {
                _ = sel.intervals.swapRemove(i - 1);
                try sel.addLoop(index);
                return;
            }
            if (interval.a == path.next(segment)) {
                _ = sel.intervals.swapRemove(i - 1);
                b = interval.b;
            }
            if (interval.b == segment) {
                _ = sel.intervals.swapRemove(i - 1);
                a = interval.a;
            }
        }
    }
    try sel.addInterval(index, .{ .a = a, .b = b });
}

pub fn toggleWhole(sel: *Selection, index: u32, path: geometry.Path) !void {
    for (sel.loops.items) |loop_index, i| {
        if (loop_index == index) {
            _ = sel.loops.swapRemove(i);
            return;
        }
    }
    var i = sel.intervals.len;
    while (i > 0) : (i -= 1) {
        if (sel.intervals.items(.index)[i - 1] == index) {
            const interval = sel.intervals.items(.interval)[i - 1];
            _ = sel.intervals.swapRemove(i - 1);
            if (!path.isLooped() and interval.a == 0 and interval.b == path.len() - 1)
                return;
        }
    }
    if (path.isLooped()) {
        try sel.addLoop(index);
    } else {
        try sel.addInterval(index, .{ .a = 0, .b = path.len() - 1 });
    }
}

pub fn selectAll(sel: *Selection, drawing: Drawing) !void {
    sel.clear();
    var it = drawing.pathIterator();
    while (it.next()) |path| {
        if (path.isLooped()) {
            try sel.addLoop(it.getIndex());
        } else {
            try sel.addInterval(it.getIndex(), .{ .a = 0, .b = path.len() - 1 });
        }
    }
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
