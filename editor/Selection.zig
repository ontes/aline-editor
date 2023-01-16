const std = @import("std");
const math = @import("math");
const render = @import("render");

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

    pub fn isSingleSegment(interval: Interval, path: math.Path) bool {
        return interval.a + 1 == interval.b or (path.isLooped() and path.next(interval.a) == interval.b);
    }

    pub fn isLooseEnd(interval: Interval, path: math.Path) bool {
        return interval.isSingleNode() and !path.isLooped() and
            (interval.a == 0 or interval.a == path.len() - 1);
    }
};

const Selection = @This();

drawing: Drawing,
loops: std.ArrayListUnmanaged(u32) = .{},
intervals: std.MultiArrayList(struct { index: u32, interval: Interval }) = .{},

pub fn init(allocator: std.mem.Allocator) Selection {
    return .{ .drawing = Drawing.init(allocator) };
}

pub fn deinit(sel: Selection) void {
    var sel_ = sel;
    sel_.loops.deinit(sel.drawing.allocator);
    sel_.intervals.deinit(sel.drawing.allocator);
    sel.drawing.deinit();
}

pub fn clone(sel: Selection) !Selection {
    var sel_ = sel;
    return .{
        .drawing = try sel.drawing.clone(),
        .loops = try sel_.loops.clone(sel.drawing.allocator),
        .intervals = try sel.intervals.clone(sel.drawing.allocator),
    };
}

pub fn cloneWithNothingSelected(sel: Selection) !Selection {
    return .{ .drawing = try sel.drawing.clone() };
}

pub fn isNothingSelected(sel: Selection) bool {
    return sel.loops.items.len == 0 and sel.intervals.len == 0;
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
    try sel.loops.append(sel.drawing.allocator, index);
}
fn addInterval(sel: *Selection, index: u32, interval: Interval) !void {
    try sel.intervals.append(sel.drawing.allocator, .{ .index = index, .interval = interval });
}

/// Selects node, assumes it isn't selected
pub fn selectNode(sel: *Selection, index: u32, node: u32) !void {
    try sel.addInterval(index, .{ .a = node, .b = node });
}

/// Selects segment, assumes it isn't selected
pub fn selectSegment(sel: *Selection, index: u32, segment: u32) !void {
    const segment_end = sel.drawing.getNext(index, segment);
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
pub fn selectPath(sel: *Selection, index: u32) !void {
    if (sel.drawing.getLooped(index)) {
        try sel.addLoop(index);
    } else {
        try sel.addInterval(index, .{ .a = 0, .b = sel.drawing.getLen(index) - 1 });
    }
}

/// Deselects node. Returns true if node was selected prior to calling.
pub fn deselectNode(sel: *Selection, index: u32, node: u32) !bool {
    for (sel.loops.items) |loop_index, i| {
        if (loop_index == index) {
            _ = sel.loops.swapRemove(i);
            try sel.addInterval(index, .{ .a = sel.drawing.getNext(index, node), .b = sel.drawing.getPrev(index, node) });
            return true;
        }
    }
    for (sel.intervals.items(.index)) |interval_index, i| {
        if (interval_index == index) {
            const interval = sel.intervals.items(.interval)[i];
            if (interval.containsNode(node)) {
                _ = sel.intervals.swapRemove(i);
                if (interval.a != node)
                    try sel.addInterval(index, .{ .a = interval.a, .b = sel.drawing.getPrev(index, node) });
                if (interval.b != node)
                    try sel.addInterval(index, .{ .a = sel.drawing.getNext(index, node), .b = interval.b });
                return true;
            }
        }
    }
    return false;
}

/// Deselects segment. Returns true if segment was selected prior to calling.
pub fn deselectSegment(sel: *Selection, index: u32, segment: u32) !bool {
    const segment_end = sel.drawing.getNext(index, segment);
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
pub fn deselectPath(sel: *Selection, index: u32) !bool {
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
            if (!sel.drawing.getLooped(index) and interval.a == 0 and interval.b == sel.drawing.getLen(index) - 1)
                return true;
        }
    }
    return false;
}

/// Selects node if not selected, deselects it otherwise.
pub fn toggleNode(sel: *Selection, index: u32, node: u32) !void {
    if (!try sel.deselectNode(index, node))
        try sel.selectNode(index, node);
}

/// Selects segment if not selected, deselects it otherwise.
pub fn toggleSegment(sel: *Selection, index: u32, segment: u32) !void {
    if (!try sel.deselectSegment(index, segment))
        try sel.selectSegment(index, segment);
}

/// Selects path if not selected, deselects it otherwise.
pub fn togglePath(sel: *Selection, index: u32) !void {
    if (!try sel.deselectPath(index))
        try sel.selectPath(index);
}

pub fn deselectAll(sel: *Selection) void {
    sel.loops.clearRetainingCapacity();
    sel.intervals.shrinkRetainingCapacity(0);
}

pub fn selectAll(sel: *Selection) !void {
    sel.deselectAll();
    var index: u32 = 0;
    while (index < sel.drawing.entries.len) : (index += 1)
        try sel.selectPath(index);
}

pub fn generateSelected(sel: Selection, gen: anytype) !void {
    for (sel.loops.items) |index| {
        try sel.drawing.getPath(index).generate(gen);
    }
    for (sel.intervals.items(.index)) |index, j| {
        const interval = sel.intervals.items(.interval)[j];
        const path = sel.drawing.getPath(index);
        var pass = gen.begin();
        var i: u32 = interval.a;
        while (i != interval.b) : (i = path.next(i))
            try pass.add(path.positions[i], path.angles[i]);
        try pass.end(path.positions[i], null);
    }
}

pub fn transformSelected(sel: *Selection, mat: math.Mat3) void {
    for (sel.loops.items) |index| {
        for (sel.drawing.getPositions(index)) |*pos|
            pos.* = math.transform(mat, pos.*);
    }
    for (sel.intervals.items(.index)) |index, i| {
        const interval = sel.intervals.items(.interval)[i];
        const positions = sel.drawing.getPositions(index);
        var node = interval.a;
        while (node != interval.b) : (node = (node + 1) % @intCast(u32, positions.len))
            positions[node] = math.transform(mat, positions[node]);
        positions[node] = math.transform(mat, positions[node]);
    }
}

pub fn generateTransformEdges(sel: Selection, mat: math.Mat3, gen: anytype) !void {
    for (sel.intervals.items(.index)) |index, j| {
        const interval = sel.intervals.items(.interval)[j];
        const path = sel.drawing.getPath(index);
        if ((path.isLooped() or interval.a > 0) and !sel.isSelectedNode(index, path.prev(interval.a))) {
            var arc = path.getArc(path.prev(interval.a));
            arc.pos_b = math.transform(mat, arc.pos_b);
            try arc.generate(gen);
        }
        if (path.isLooped() or interval.b < path.len() - 1) {
            var arc = path.getArc(interval.b);
            arc.pos_a = math.transform(mat, arc.pos_a);
            if (sel.isSelectedNode(index, path.next(interval.b)))
                arc.pos_b = math.transform(mat, arc.pos_b);
            try arc.generate(gen);
        }
    }
}
