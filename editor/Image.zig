const std = @import("std");
const math = @import("math");
const render = @import("render");

const Image = @This();

allocator: std.mem.Allocator,
props: std.MultiArrayList(Path.Properties) = .{},
nodes: std.MultiArrayList(Path.Node) = .{},

pub fn init(allocator: std.mem.Allocator) Image {
    return .{ .allocator = allocator };
}

pub fn initCapacity(allocator: std.mem.Allocator, props_len: usize, nodes_len: usize) !Image {
    var image = init(allocator);
    try image.props.ensureTotalCapacity(allocator, props_len);
    try image.nodes.ensureTotalCapacity(allocator, nodes_len);
    return image;
}

pub fn deinit(image: Image) void {
    var image_ = image;
    image_.props.deinit(image.allocator);
    image_.nodes.deinit(image.allocator);
}

pub fn clone(image: Image) !Image {
    return .{ .allocator = image.allocator, .props = try image.props.clone(image.allocator), .nodes = try image.nodes.clone(image.allocator) };
}

fn getDataOffset(image: Image, index: usize) usize {
    var offset: usize = 0;
    for (image.props.items(.node_count)[0..index]) |count|
        offset += count;
    return offset;
}

pub fn len(image: Image) usize {
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
        style: Style,
        name: Name,
    };

    pub const Node = struct {
        position: math.Vec2,
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
        return p.image.nodes.items(.position)[offset .. offset + p.getNodeCount()];
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

pub fn addImageSlice(image: *Image, src_image: Image, from: usize, to: usize) !void {
    const props_offset = image.props.len;
    try image.props.resize(image.allocator, props_offset + to - from);
    std.mem.copy(usize, image.props.items(.node_count)[props_offset..], src_image.props.items(.node_count)[from..to]);
    std.mem.copy(Path.Style, image.props.items(.style)[props_offset..], src_image.props.items(.style)[from..to]);
    std.mem.copy(Path.Name, image.props.items(.name)[props_offset..], src_image.props.items(.name)[from..to]);

    const nodes_offset = image.nodes.len;
    const nodes_from = src_image.getDataOffset(from);
    const nodes_to = src_image.getDataOffset(to);
    try image.nodes.resize(image.allocator, nodes_offset + nodes_to - nodes_from);
    std.mem.copy(math.Vec2, image.nodes.items(.position)[nodes_offset..], src_image.nodes.items(.position)[nodes_from..nodes_to]);
    std.mem.copy(f32, image.nodes.items(.angle)[nodes_offset..], src_image.nodes.items(.angle)[nodes_from..nodes_to]);
}

pub fn addImage(image: *Image, src_image: Image) !void {
    return image.addImageSlice(src_image, 0, src_image.len());
}

pub fn addEmptyPath(image: *Image, style: Path.Style, name: Path.Name) !void {
    return image.props.append(image.allocator, .{ .node_count = 0, .style = style, .name = name });
}

pub fn appendNodes(image: *Image, positions: []const math.Vec2, angles: []const f32, reversed: bool) !void {
    std.debug.assert(positions.len == angles.len);
    const offset = image.nodes.len;
    try image.nodes.resize(image.allocator, offset + positions.len);
    if (!reversed) {
        std.mem.copy(math.Vec2, image.nodes.items(.position)[offset..], positions);
        std.mem.copy(f32, image.nodes.items(.angle)[offset..], angles);
    } else {
        for (positions) |pos, i|
            image.nodes.items(.position)[image.nodes.len - i - 1] = pos;
        for (angles[0 .. angles.len - 1]) |ang, i|
            image.nodes.items(.angle)[image.nodes.len - i - 2] = -ang;
        image.nodes.items(.angle)[image.nodes.len - 1] = -angles[angles.len - 1];
    }
    image.props.items(.node_count)[image.len() - 1] += positions.len;
}

pub fn appendNode(image: *Image, node: Path.Node) !void {
    return image.appendNodes(&.{node.position}, &.{node.angle}, false);
}

pub fn setLastAngle(image: Image, angle: f32) void {
    image.nodes.items(.angle)[image.nodes.len - 1] = angle;
}

/// Add new path containing a single point
pub fn operationAddPoint(image: Image, pos: math.Vec2, style: Path.Style, name: Path.Name) !Image {
    var out = try Image.initCapacity(image.allocator, image.props.len + 1, image.nodes.len + 1);
    out.addImage(image) catch unreachable;
    out.addEmptyPath(style, name) catch unreachable;
    out.appendNode(.{ .position = pos }) catch unreachable;
    return out;
}

/// Append point to the last path
pub fn operationAppendPoint(image: Image, index: usize, reverse: bool, angle: f32, pos: math.Vec2) !Image {
    const path = image.getComp(index);
    var out = try Image.initCapacity(image.allocator, image.props.len, image.nodes.len + 1);
    out.addImageSlice(image, 0, index) catch unreachable;
    out.addEmptyPath(path.getStyle(), path.getName()) catch unreachable;
    out.appendNodes(path.getPositions(), path.getAngles(), reverse) catch unreachable;
    out.setLastAngle(angle);
    out.appendNode(.{ .position = pos }) catch unreachable;
    out.addImageSlice(image, index + 1, image.len()) catch unreachable;
    return out;
}

/// Add segment from last to first node of the last path
pub fn operationLoopPath(image: Image, index: usize, angle: f32) !Image {
    var out = try Image.initCapacity(image.allocator, image.props.len, image.nodes.len);
    out.addImageSlice(image, 0, index + 1) catch unreachable;
    out.setLastAngle(angle);
    out.addImageSlice(image, index + 1, image.len()) catch unreachable;
    return out;
}

/// Appends path on index_b after path on index_a
pub fn operationConnectPaths(image: Image, index_a: usize, reverse_a: bool, index_b: usize, reverse_b: bool, angle: f32) !Image {
    std.debug.assert(index_a != index_b);
    const path_a = image.getComp(index_a);
    const path_b = image.getComp(index_b);
    var out = try Image.initCapacity(image.allocator, image.props.len - 1, image.nodes.len);
    if (index_a < index_b) {
        out.addImageSlice(image, 0, index_a) catch unreachable;
    } else {
        out.addImageSlice(image, 0, index_b) catch unreachable;
        out.addImageSlice(image, index_b + 1, index_a) catch unreachable;
    }
    out.addEmptyPath(path_a.getStyle(), path_b.getName()) catch unreachable;
    out.appendNodes(path_a.getPositions(), path_b.getAngles(), reverse_a) catch unreachable;
    out.setLastAngle(angle);
    out.appendNodes(path_b.getPositions(), path_b.getAngles(), reverse_b) catch unreachable;
    if (index_a < index_b) {
        out.addImageSlice(image, index_a + 1, index_b) catch unreachable;
        out.addImageSlice(image, index_b + 1, image.len()) catch unreachable;
    } else {
        out.addImageSlice(image, index_a + 1, image.len()) catch unreachable;
    }
    return out;
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
