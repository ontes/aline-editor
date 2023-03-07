const std = @import("std");
const math = @import("math");
const render = @import("render");

const Image = @import("Image.zig");

const ImageSelection = @This();

image: Image,
props: std.MultiArrayList(PathSelection.Properties) = .{},

pub fn init(allocator: std.mem.Allocator) ImageSelection {
    return .{ .image = Image.init(allocator) };
}

pub fn deinit(is: ImageSelection) void {
    var is_ = is;
    is_.props.deinit(is.image.allocator);
    is.image.deinit();
}

pub fn clone(is: ImageSelection) !ImageSelection {
    return .{ .image = try is.image.clone(), .props = try is.props.clone(is.image.allocator) };
}

pub fn len(is: ImageSelection) usize {
    return is.props.len;
}

pub const PathSelection = struct {
    pub const Properties = struct {
        path_index: usize,
        a: usize = 0,
        b: usize = std.math.maxInt(usize),
    };

    path: Image.Path,
    a: usize = 0,
    b: usize = std.math.maxInt(usize),

    pub fn isLooped(ps: PathSelection) bool {
        return ps.b == std.math.maxInt(usize);
    }
    pub fn containsNode(ps: PathSelection, node_index: usize) bool {
        const a = node_index >= ps.a;
        const b = node_index <= ps.b;
        return if (ps.a <= ps.b) a and b else a or b;
    }
    pub fn containsSegment(ps: PathSelection, segment_index: usize) bool {
        return ps.containsNode(segment_index) and segment_index != ps.b;
    }
    pub fn isSingleNode(ps: PathSelection) bool {
        return ps.a == ps.b;
    }
    pub fn isSingleSegment(ps: PathSelection) bool {
        return ps.a + 1 == ps.b or (ps.path.isLooped() and ps.path.nextNode(ps.a) == ps.b);
    }
    pub fn isLooseEnd(ps: PathSelection) bool {
        return ps.isSingleNode() and !ps.path.isLooped() and (ps.a == 0 or ps.a == ps.path.getNodeCount() - 1);
    }
    pub fn isWholePath(ps: PathSelection) bool {
        return ps.isLooped() or (!ps.path.isLooped() and ps.a == 0 and ps.b == ps.path.getNodeCount() - 1);
    }
};

pub fn get(is: *const ImageSelection, i: usize) PathSelection {
    const props = is.props.get(i);
    return .{ .path = is.image.get(props.path_index), .a = props.a, .b = props.b };
}
pub fn getComp(is: *const ImageSelection, i: usize) PathSelection {
    const props = is.props.get(i);
    return .{ .path = is.image.getComp(props.path_index), .a = props.a, .b = props.b };
}

pub const Iterator = struct {
    is: *const ImageSelection,
    path: Image.Path,
    index: usize = 0,

    pub fn next(it: *Iterator) ?PathSelection {
        if (it.index >= it.is.len())
            return null;
        while (it.is.props.items(.path_index)[it.index] != it.path.index) {
            it.index += 1;
            if (it.index >= it.is.len())
                return null;
        }
        const ps = it.is.get(it.index);
        it.index += 1;
        return ps;
    }
};
pub fn iterator(is: *const ImageSelection, path: Image.Path) Iterator {
    return .{ .is = is, .path = path };
}

pub fn isNodeSelected(is: ImageSelection, path_index: usize, node: usize) bool {
    var it = is.iterator(is.image.get(path_index));
    while (it.next()) |ps| {
        if (ps.containsNode(node))
            return true;
    }
    return false;
}

pub fn isSegmentSelected(is: ImageSelection, path_index: usize, segment: usize) bool {
    var it = is.iterator(is.image.get(path_index));
    while (it.next()) |ps| {
        if (ps.containsSegment(segment))
            return true;
    }
    return false;
}

pub fn isPathSelected(is: ImageSelection, path_index: usize) bool {
    var it = is.iterator(is.image.getComp(path_index));
    while (it.next()) |ps| {
        if (ps.isWholePath())
            return true;
    }
    return false;
}

pub fn isPathPartiallySelected(is: ImageSelection, path_index: usize) bool {
    var it = is.iterator(is.image.get(path_index));
    return it.next() != null;
}

fn addInterval(is: *ImageSelection, path_index: usize, a: usize, b: usize) !void {
    try is.props.append(is.image.allocator, .{ .path_index = path_index, .a = a, .b = b });
}
fn addLoop(is: *ImageSelection, path_index: usize) !void {
    try is.props.append(is.image.allocator, .{ .path_index = path_index });
}

/// Selects node, assumes it isn't selected
pub fn selectNode(is: *ImageSelection, path_index: usize, node: usize) !void {
    try is.addInterval(path_index, node, node);
}

/// Selects segment, assumes it isn't selected
pub fn selectSegment(is: *ImageSelection, path_index: usize, segment: usize) !void {
    const segment_end = is.image.get(path_index).nextNode(segment);
    var a = segment;
    var b = segment_end;
    var i = is.len();
    while (i > 0) : (i -= 1) {
        if (is.props.items(.path_index)[i - 1] == path_index) {
            const ps = is.get(i - 1);
            if (ps.a == segment_end and ps.b == segment) {
                _ = is.props.swapRemove(i - 1);
                try is.addLoop(path_index);
                return;
            }
            if (ps.a == segment_end) {
                _ = is.props.swapRemove(i - 1);
                b = ps.b;
            }
            if (ps.b == segment) {
                _ = is.props.swapRemove(i - 1);
                a = ps.a;
            }
        }
    }
    try is.addInterval(path_index, a, b);
}

/// Selects path, assumes no part of it is selected
pub fn selectPath(is: *ImageSelection, path_index: usize) !void {
    const path = is.image.get(path_index);
    if (path.isLooped()) {
        try is.addLoop(path_index);
    } else {
        try is.addInterval(path_index, 0, path.getNodeCount() - 1);
    }
}

/// Deselects node. Returns true if node was selected prior to calling.
pub fn deselectNode(is: *ImageSelection, path_index: usize, node: usize) !bool {
    const path = is.image.get(path_index);
    var i: usize = 0;
    while (i < is.len()) : (i += 1) {
        if (is.props.items(.path_index)[i] == path_index) {
            const ps = is.get(i);
            if (ps.containsNode(node)) {
                _ = is.props.swapRemove(i);
                if (ps.isLooped()) {
                    try is.addInterval(path_index, path.nextNode(node), path.prevNode(node));
                } else {
                    if (ps.a != node)
                        try is.addInterval(path_index, ps.a, path.prevNode(node));
                    if (ps.b != node)
                        try is.addInterval(path_index, path.nextNode(node), ps.b);
                }
                return true;
            }
        }
    }
    return false;
}

/// Deselects segment. Returns true if segment was selected prior to calling.
pub fn deselectSegment(is: *ImageSelection, path_index: usize, segment: usize) !bool {
    const path = is.image.get(path_index);
    const segment_end = path.nextNode(segment);
    var i: usize = 0;
    while (i < is.len()) : (i += 1) {
        if (is.props.items(.path_index)[i] == path_index) {
            const ps = is.get(i);
            if (ps.containsSegment(segment)) {
                _ = is.props.swapRemove(i);
                if (ps.isLooped()) {
                    try is.addInterval(path_index, segment_end, segment);
                } else {
                    if (ps.a != segment)
                        try is.addInterval(path_index, ps.a, segment);
                    if (ps.b != segment_end)
                        try is.addInterval(path_index, segment_end, ps.b);
                }
                return true;
            }
        }
    }
    return false;
}

/// Deselects path. Returns true if entire path was selected prior to calling.
pub fn deselectPath(is: *ImageSelection, path_index: usize) !bool {
    var i = is.len();
    while (i > 0) : (i -= 1) {
        if (is.props.items(.path_index)[i - 1] == path_index) {
            const ps = is.get(i - 1);
            _ = is.props.swapRemove(i - 1);
            if (ps.isWholePath())
                return true;
        }
    }
    return false;
}

/// Selects node if not selected, deselects it otherwise.
pub fn toggleNode(is: *ImageSelection, path_index: usize, node: usize) !void {
    if (!try is.deselectNode(path_index, node))
        try is.selectNode(path_index, node);
}

/// Selects segment if not selected, deselects it otherwise.
pub fn toggleSegment(is: *ImageSelection, path_index: usize, segment: usize) !void {
    if (!try is.deselectSegment(path_index, segment))
        try is.selectSegment(path_index, segment);
}

/// Selects path if not selected, deselects it otherwise.
pub fn togglePath(is: *ImageSelection, path_index: usize) !void {
    if (!try is.deselectPath(path_index))
        try is.selectPath(path_index);
}

pub fn deselectAll(is: *ImageSelection) void {
    is.props.shrinkRetainingCapacity(0);
}

pub fn selectAll(is: *ImageSelection) !void {
    is.deselectAll();
    var path_index: usize = 0;
    while (path_index < is.image.len()) : (path_index += 1)
        try is.selectPath(path_index);
}

pub fn generateSelected(is: ImageSelection, gen: anytype) !void {
    var i: usize = 0;
    while (i < is.len()) : (i += 1) {
        const ps = is.getComp(i);
        if (ps.isLooped()) {
            try ps.path.generate(gen);
        } else {
            var pass = try gen.begin();
            var node = ps.a;
            while (node != ps.b) : (node = ps.path.nextNode(node))
                try pass.add(ps.path.getPos(node), ps.path.getAng(node));
            try pass.add(ps.path.getPos(node), std.math.nan_f32);
            try pass.end();
        }
    }
}

pub fn transformSelected(is: *ImageSelection, mat: math.Mat3) void {
    const mat_det = math.mat3.determinant(mat);
    var i: usize = 0;
    while (i < is.len()) : (i += 1) {
        const ps = is.getComp(i);
        if (ps.isLooped()) {
            for (ps.path.getPositions()) |*pos|
                pos.* = math.transform(mat, pos.*);
            for (ps.path.getAngles()) |*ang|
                ang.* *= std.math.sign(mat_det);
        } else {
            var node = ps.a;
            while (node != ps.b) : (node = ps.path.nextNode(node)) {
                ps.path.getPositions()[node] = math.transform(mat, ps.path.getPos(node));
                ps.path.getAngles()[node] *= std.math.sign(mat_det);
            }
            ps.path.getPositions()[node] = math.transform(mat, ps.path.getPos(node));
        }
    }
}

pub fn generateTransformEdges(is: ImageSelection, mat: math.Mat3, gen: anytype) !void {
    var i: usize = 0;
    while (i < is.len()) : (i += 1) {
        const ps = is.getComp(i);
        if (ps.isLooped()) continue;
        if ((ps.path.isLooped() or ps.a > 0) and !is.isNodeSelected(i, ps.path.prevNode(ps.a))) {
            var arc = ps.path.getArc(ps.path.prevNode(ps.a));
            arc.pos_b = math.transform(mat, arc.pos_b);
            try arc.generate(gen);
        }
        if (ps.path.isLooped() or ps.b + 1 < ps.path.getNodeCount()) {
            var arc = ps.path.getArc(ps.b);
            arc.pos_a = math.transform(mat, arc.pos_a);
            if (is.isNodeSelected(i, ps.path.nextNode(ps.b)))
                arc.pos_b = math.transform(mat, arc.pos_b);
            try arc.generate(gen);
        }
    }
}

pub fn getBoundingBox(is: ImageSelection) [2]math.Vec2 {
    var min_pos: math.Vec2 = .{ std.math.inf_f32, std.math.inf_f32 };
    var max_pos: math.Vec2 = .{ -std.math.inf_f32, -std.math.inf_f32 };
    is.generateSelected(math.boundingBoxGenerator(&min_pos, &max_pos)) catch unreachable;
    return .{ min_pos, max_pos };
}

pub fn getAveragePoint(is: ImageSelection) math.Vec2 {
    var sum: math.Vec2 = .{ 0, 0 };
    var count: usize = 0;
    is.generateSelected(math.pointSumGenerator(&sum, &count)) catch unreachable;
    return sum / math.vec2.splat(@intToFloat(f32, count));
}
