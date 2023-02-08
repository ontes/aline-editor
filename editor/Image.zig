const std = @import("std");
const math = @import("math");
const render = @import("render");

const Image = @This();

allocator: std.mem.Allocator,
props: std.MultiArrayList(Path.Properties) = .{},
nodes: std.MultiArrayList(Path.Node) = .{},

pub inline fn init(allocator: std.mem.Allocator) Image {
    return .{ .allocator = allocator };
}

pub fn deinit(image: Image) void {
    var drawing_ = image;
    drawing_.props.deinit(image.allocator);
    drawing_.nodes.deinit(image.allocator);
}

fn getDataOffset(image: Image, index: usize) usize {
    var offset: usize = 0;
    for (image.props.items(.node_count)[0..index]) |count|
        offset += count;
    return offset;
}

pub fn getPathCount(image: Image) usize {
    return image.props.len;
}

pub const Path = struct {
    pub const Style = struct {
        fill_color: [4]f32,
        stroke_color: [4]f32,
        stroke: math.Stroke,

        pub fn isFilled(style: Style) bool {
            return style.fill_color[3] > 0;
        }
    };

    pub const Name = [16]u8;

    pub const Properties = struct {
        node_count: usize,
        style: Path.Style,
        name: Path.Name,
    };

    pub const Node = struct {
        pos: math.Vec2,
        angle: f32 = std.math.nan_f32,
    };

    image: *const Image,
    index: usize,
    offset: ?usize = null,

    pub fn getNodeCount(p: Path) usize {
        return p.image.props.items(.node_count)[p.index];
    }
    pub fn getStyle(p: Path) Style {
        return p.image.props.items(.style)[p.index];
    }
    pub fn getName(p: Path) Name {
        return p.image.props.items(.name)[p.index];
    }

    pub fn nextNode(p: Path, node_index: usize) usize {
        return (node_index + 1) % p.getNodeCount();
    }
    pub fn prevNode(p: Path, node_index: usize) usize {
        return (node_index + p.getNodeCount() - 1) % p.getNodeCount();
    }

    fn getDataOffset(p: Path) usize {
        return p.offset orelse p.image.getDataOffset(p.index);
    }

    pub fn getPositions(p: Path) []math.Vec2 {
        const offset = p.getDataOffset();
        return p.image.nodes.items(.pos)[offset .. offset + p.getNodeCount()];
    }
    pub fn getAngles(p: Path) []f32 {
        const offset = p.getDataOffset();
        return p.image.nodes.items(.angle)[offset .. offset + p.getNodeCount()];
    }

    pub fn getPos(p: Path, index: usize) math.Vec2 {
        return p.getPositions()[index];
    }
    pub fn getAng(p: Path, index: usize) f32 {
        return p.getAngles()[index];
    }
    pub fn getArc(p: Path, index: usize) math.Arc {
        std.debug.assert(p.offset != null);
        return .{
            .pos_a = p.getPos(index),
            .angle = p.getAng(index),
            .pos_b = p.getPos(p.nextNode(index)),
        };
    }

    pub fn isLooped(p: Path) bool {
        std.debug.assert(p.offset != null);
        return !std.math.isNan(p.getAng(p.getNodeCount() - 1));
    }
    pub fn getSegmentCount(p: Path) usize {
        std.debug.assert(p.offset != null);
        return if (p.isLooped()) p.getNodeCount() else p.getNodeCount() - 1;
    }

    pub fn generate(p: Path, gen: anytype) !void {
        std.debug.assert(p.offset != null);
        var pass = gen.begin();
        var i: usize = 0;
        while (i < p.getNodeCount()) : (i += 1)
            try pass.add(p.getPos(i), p.getAng(i));
        try pass.end();
    }

    pub fn draw(p: Path, buffer: *render.Buffer) !void {
        const style = p.getStyle();
        if (p.isLooped())
            try p.generate(buffer.generator(style.fill_color));
        try p.generate(style.stroke.generator(buffer.generator(style.stroke_color)));
    }

    // In-situ reverse path data (shoud not change the path visually)
    pub fn reverse(p: Path) void {
        std.debug.assert(p.offset != null);
        const positions = p.getPositions();
        const angles = p.getAngles();
        var i: usize = 0;
        while (i < p.getNodeCount() / 2) : (i += 1) {
            std.mem.swap(math.Vec2, &positions[i], &positions[p.getNodeCount() - i - 1]);
            std.mem.swap(f32, &angles[i], &angles[p.getNodeCount() - i - 2]);
        }
        for (angles) |*angle|
            angle.* = -angle.*;
    }

    // TODO: rework this into a generator
    pub fn containsPoint(p: Path, point_pos: math.Vec2) bool {
        std.debug.assert(p.offset != null);
        std.debug.assert(p.isLooped());
        var inside = false;
        var index: usize = 0;
        while (index < p.getSegmentCount()) : (index += 1) {
            const arc = p.getArc(index);
            const point_angle = arc.angleOnPoint(point_pos);
            if (std.math.sign(point_angle) == std.math.sign(arc.pos_a[0] - point_pos[0]) and
                std.math.sign(point_angle) == std.math.sign(point_pos[0] - arc.pos_b[0]))
                inside = !inside;
            if (std.math.sign(point_angle) == std.math.sign(arc.angle) and @fabs(point_angle) < @fabs(arc.angle))
                inside = !inside;
        }
        return inside;
    }
};

pub fn get(image: *const Image, index: usize) Path {
    return .{ .image = image, .index = index };
}
pub fn getComp(image: *const Image, index: usize) Path {
    return .{ .image = image, .index = index, .offset = image.getDataOffset(index) };
}

pub fn addPoint(image: *Image, pos: math.Vec2, style: Path.Style, name: Path.Name) !void {
    try image.nodes.append(image.allocator, .{ .pos = pos });
    try image.props.append(image.allocator, .{ .node_count = 1, .style = style, .name = name });
}

pub fn appendPoint(image: *Image, index: usize, pos: math.Vec2, angle: f32) !void {
    const offset = image.getDataOffset(index);
    image.nodes.items(.angle)[offset + image.get(index).getNodeCount() - 1] = angle;
    try image.nodes.insert(image.allocator, offset + image.get(index).getNodeCount(), .{ .pos = pos });
    image.props.items(.node_count)[index] += 1;
}

/// Add segment from last to first node
pub fn loopPath(image: *Image, index: usize, angle: f32) void {
    image.nodes.items(.angle)[image.getDataOffset(index) + image.get(index).getNodeCount() - 1] = angle;
}

pub fn joinPaths(image: *Image, index_a: usize, index_b: usize, angle: f32) usize {
    if (index_a == index_b) {
        image.loopPath(index_a, angle);
        return index_a;
    }
    const new_index = if (index_a < index_b) index_a else index_a - 1;
    // image.reorder(index_b, new_index + 1);
    // image.nodes.items[image.getDataOffset(new_index) + image.get(new_index).getNodeCount() - 1].angle = angle;
    // image.props.items(.node_count)[new_index] += image.props.items(.node_count)[new_index + 1];
    // image.props.orderedRemove(new_index + 1);
    return new_index;
}

pub fn clear(image: *Image) void {
    image.nodes.shrinkRetainingCapacity(0);
    image.props.shrinkRetainingCapacity(0);
}

pub fn clone(image: Image) !Image {
    var _drawing = image;
    return .{
        .allocator = image.allocator,
        .props = try _drawing.props.clone(image.allocator),
        .nodes = try _drawing.nodes.clone(image.allocator),
    };
}

const Iterator = struct {
    image: *const Image,
    index: usize = 0,
    offset: usize = 0,

    pub fn next(it: *Iterator) ?Path {
        if (it.index >= it.image.props.len)
            return null;
        const path = Path{ .image = it.image, .index = it.index, .offset = it.offset };
        it.offset += it.image.get(it.index).getNodeCount();
        it.index += 1;
        return path;
    }
};
pub inline fn iterator(image: *const Image) Iterator {
    return .{ .image = image };
}

const ReversedIterator = struct {
    image: *const Image,
    index: usize,
    offset: usize,

    pub fn next(it: *ReversedIterator) ?Path {
        if (it.index == 0)
            return null;
        it.index -= 1;
        it.offset -= it.image.get(it.index).getNodeCount();
        return Path{ .image = it.image, .index = it.index, .offset = it.offset };
    }
};
pub fn reversedIterator(image: *const Image) ReversedIterator {
    return .{ .image = image, .index = image.props.len, .offset = image.nodes.len };
}

pub fn draw(image: Image, buffer: *render.Buffer) !void {
    var it = image.iterator();
    while (it.next()) |path|
        try path.draw(buffer);
}
