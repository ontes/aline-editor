const std = @import("std");
const math = @import("math");
const render = @import("render");

const Image = @import("Image.zig");

pub const Interval = struct {
    a: usize,
    b: usize,

    pub fn containsNode(interval: Interval, node: usize) bool {
        const a = node >= interval.a;
        const b = node <= interval.b;
        return if (interval.a <= interval.b) a and b else a or b;
    }

    pub fn containsSegment(interval: Interval, segment: usize) bool {
        const a = segment >= interval.a;
        const b = segment < interval.b;
        return if (interval.a <= interval.b) a and b else a or b;
    }

    pub fn isSingleNode(interval: Interval) bool {
        return interval.a == interval.b;
    }

    pub fn isSingleSegment(interval: Interval, path: Image.Path) bool {
        return interval.a + 1 == interval.b or (path.isLooped() and path.nextNode(interval.a) == interval.b);
    }

    pub fn isLooseEnd(interval: Interval, path: Image.Path) bool {
        return interval.isSingleNode() and !path.isLooped() and
            (interval.a == 0 or interval.a == path.getNodeCount() - 1);
    }
};

const ImageSelection = @This();

image: Image,
loops: std.ArrayListUnmanaged(usize) = .{},
intervals: std.MultiArrayList(struct { index: usize, interval: Interval }) = .{},

pub fn init(allocator: std.mem.Allocator) ImageSelection {
    return .{ .image = Image.init(allocator) };
}

pub fn deinit(sel: ImageSelection) void {
    var sel_ = sel;
    sel_.loops.deinit(sel.image.allocator);
    sel_.intervals.deinit(sel.image.allocator);
    sel.image.deinit();
}

pub fn clone(sel: ImageSelection) !ImageSelection {
    var sel_ = sel;
    return .{
        .image = try sel.image.clone(),
        .loops = try sel_.loops.clone(sel.image.allocator),
        .intervals = try sel.intervals.clone(sel.image.allocator),
    };
}

pub fn cloneWithNothingSelected(sel: ImageSelection) !ImageSelection {
    return .{ .image = try sel.image.clone() };
}

pub fn getLoopCount(sel: ImageSelection) usize {
    return sel.loops.items.len;
}
pub fn getIntervalCount(sel: ImageSelection) usize {
    return sel.intervals.len;
}
pub fn getTotalCount(sel: ImageSelection) usize {
    return sel.getLoopCount() + sel.getIntervalCount();
}

pub fn isNodeSelected(sel: ImageSelection, index: usize, node: usize) bool {
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

pub fn isSegmentSelected(sel: ImageSelection, index: usize, segment: usize) bool {
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

pub fn isPathSelected(sel: ImageSelection, index: usize) bool {
    if (sel.image.get(index).isLooped()) {
        for (sel.loops.items) |loop_index| {
            if (loop_index == index)
                return true;
        }
    } else {
        for (sel.intervals.items(.index)) |interval_index, i| {
            if (interval_index == index and sel.intervals.items(.interval)[i].a == 0 and
                sel.intervals.items(.interval)[i].b == sel.image.get(interval_index).getNodeCount() - 1)
                return true;
        }
    }
    return false;
}

pub fn isPathPartiallySelected(sel: ImageSelection, index: usize) bool {
    for (sel.loops.items) |loop_index| {
        if (loop_index == index)
            return true;
    }
    for (sel.intervals.items(.index)) |interval_index| {
        if (interval_index == index)
            return true;
    }
    return false;
}

fn addLoop(sel: *ImageSelection, index: usize) !void {
    try sel.loops.append(sel.image.allocator, index);
}
fn addInterval(sel: *ImageSelection, index: usize, interval: Interval) !void {
    try sel.intervals.append(sel.image.allocator, .{ .index = index, .interval = interval });
}

/// Selects node, assumes it isn't selected
pub fn selectNode(sel: *ImageSelection, index: usize, node: usize) !void {
    try sel.addInterval(index, .{ .a = node, .b = node });
}

/// Selects segment, assumes it isn't selected
pub fn selectSegment(sel: *ImageSelection, index: usize, segment: usize) !void {
    const segment_end = sel.image.get(index).nextNode(segment);
    var a = segment;
    var b = segment_end;
    var i = sel.getIntervalCount();
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
pub fn selectPath(sel: *ImageSelection, index: usize) !void {
    if (sel.image.getComp(index).isLooped()) {
        try sel.addLoop(index);
    } else {
        try sel.addInterval(index, .{ .a = 0, .b = sel.image.get(index).getNodeCount() - 1 });
    }
}

/// Deselects node. Returns true if node was selected prior to calling.
pub fn deselectNode(sel: *ImageSelection, index: usize, node: usize) !bool {
    for (sel.loops.items) |loop_index, i| {
        if (loop_index == index) {
            _ = sel.loops.swapRemove(i);
            try sel.addInterval(index, .{ .a = sel.image.get(index).nextNode(node), .b = sel.image.get(index).prevNode(node) });
            return true;
        }
    }
    for (sel.intervals.items(.index)) |interval_index, i| {
        if (interval_index == index) {
            const interval = sel.intervals.items(.interval)[i];
            if (interval.containsNode(node)) {
                _ = sel.intervals.swapRemove(i);
                if (interval.a != node)
                    try sel.addInterval(index, .{ .a = interval.a, .b = sel.image.get(index).prevNode(node) });
                if (interval.b != node)
                    try sel.addInterval(index, .{ .a = sel.image.get(index).nextNode(node), .b = interval.b });
                return true;
            }
        }
    }
    return false;
}

/// Deselects segment. Returns true if segment was selected prior to calling.
pub fn deselectSegment(sel: *ImageSelection, index: usize, segment: usize) !bool {
    const segment_end = sel.image.get(index).nextNode(segment);
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
pub fn deselectPath(sel: *ImageSelection, index: usize) !bool {
    for (sel.loops.items) |loop_index, i| {
        if (loop_index == index) {
            _ = sel.loops.swapRemove(i);
            return true;
        }
    }
    var i = sel.getIntervalCount();
    while (i > 0) : (i -= 1) {
        if (sel.intervals.items(.index)[i - 1] == index) {
            const interval = sel.intervals.items(.interval)[i - 1];
            _ = sel.intervals.swapRemove(i - 1);
            if (!sel.image.get(index).isLooped() and interval.a == 0 and interval.b == sel.image.get(index).getNodeCount() - 1)
                return true;
        }
    }
    return false;
}

/// Selects node if not selected, deselects it otherwise.
pub fn toggleNode(sel: *ImageSelection, index: usize, node: usize) !void {
    if (!try sel.deselectNode(index, node))
        try sel.selectNode(index, node);
}

/// Selects segment if not selected, deselects it otherwise.
pub fn toggleSegment(sel: *ImageSelection, index: usize, segment: usize) !void {
    if (!try sel.deselectSegment(index, segment))
        try sel.selectSegment(index, segment);
}

/// Selects path if not selected, deselects it otherwise.
pub fn togglePath(sel: *ImageSelection, index: usize) !void {
    if (!try sel.deselectPath(index))
        try sel.selectPath(index);
}

pub fn deselectAll(sel: *ImageSelection) void {
    sel.loops.clearRetainingCapacity();
    sel.intervals.shrinkRetainingCapacity(0);
}

pub fn selectAll(sel: *ImageSelection) !void {
    sel.deselectAll();
    var index: usize = 0;
    while (index < sel.image.getPathCount()) : (index += 1)
        try sel.selectPath(index);
}

pub fn generateSelected(sel: ImageSelection, gen: anytype) !void {
    for (sel.loops.items) |index| {
        try sel.image.getComp(index).generate(gen);
    }
    for (sel.intervals.items(.index)) |index, j| {
        const interval = sel.intervals.items(.interval)[j];
        const path = sel.image.getComp(index);
        var pass = gen.begin();
        var i: usize = interval.a;
        while (i != interval.b) : (i = path.nextNode(i))
            try pass.add(path.getPos(i), path.getAng(i));
        try pass.add(path.getPos(i), std.math.nan_f32);
        try pass.end();
    }
}

pub fn transformSelected(sel: *ImageSelection, mat: math.Mat3) void {
    for (sel.loops.items) |index| {
        for (sel.image.get(index).getPositions()) |*pos|
            pos.* = math.transform(mat, pos.*);
    }
    for (sel.intervals.items(.index)) |index, i| {
        const interval = sel.intervals.items(.interval)[i];
        const path = sel.image.getComp(index);
        var node = interval.a;
        while (node != interval.b) : (node = path.nextNode(node))
            path.getPositions()[node] = math.transform(mat, path.getPos(node));
        path.getPositions()[node] = math.transform(mat, path.getPos(node));
    }
}

pub fn generateTransformEdges(sel: ImageSelection, mat: math.Mat3, gen: anytype) !void {
    for (sel.intervals.items(.index)) |index, j| {
        const interval = sel.intervals.items(.interval)[j];
        const path = sel.image.getComp(index);
        if ((path.isLooped() or interval.a > 0) and !sel.isNodeSelected(index, path.prevNode(interval.a))) {
            var arc = path.getArc(path.prevNode(interval.a));
            arc.pos_b = math.transform(mat, arc.pos_b);
            try arc.generate(gen);
        }
        if (path.isLooped() or interval.b < path.getNodeCount() - 1) {
            var arc = path.getArc(interval.b);
            arc.pos_a = math.transform(mat, arc.pos_a);
            if (sel.isNodeSelected(index, path.nextNode(interval.b)))
                arc.pos_b = math.transform(mat, arc.pos_b);
            try arc.generate(gen);
        }
    }
}
