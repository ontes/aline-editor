const std = @import("std");
const math = @import("math");
const render = @import("render");

pub const PathStyle = struct {
    fill_color: [4]f32,
    stroke_color: [4]f32,
    stroke: math.Stroke,

    pub fn isFilled(style: PathStyle) bool {
        return style.fill_color[3] > 0;
    }
};

pub const PathName = [16]u8;

const Image = @This();

allocator: std.mem.Allocator,
entries: std.MultiArrayList(struct { len: u32, looped: bool, style: PathStyle, name: PathName }) = .{},
data: std.MultiArrayList(struct { position: math.Vec2, angle: f32 = 0 }) = .{},

pub inline fn init(allocator: std.mem.Allocator) Image {
    return .{ .allocator = allocator };
}

pub fn deinit(image: Image) void {
    var drawing_ = image;
    drawing_.entries.deinit(image.allocator);
    drawing_.data.deinit(image.allocator);
}

pub fn pathLen(image: Image, index: u32) u32 {
    return image.entries.items(.len)[index];
}
pub fn pathIsLooped(image: Image, index: u32) bool {
    return image.entries.items(.looped)[index];
}
pub fn pathStyle(image: Image, index: u32) PathStyle {
    return image.entries.items(.style)[index];
}
pub fn pathName(image: Image, index: u32) [16]u8 {
    return image.entries.items(.name)[index];
}

pub fn pathNextNode(image: Image, index: u32, node: u32) u32 {
    return (node + 1) % image.pathLen(index);
}
pub fn pathPrevNode(image: Image, index: u32, node: u32) u32 {
    return (node + image.pathLen(index) - 1) % image.pathLen(index);
}

fn getDataOffset(image: Image, index: u32) u32 {
    var offset: u32 = 0;
    for (image.entries.items(.len)[0..index]) |len|
        offset += len;
    return offset;
}
fn pathAnglesLen(image: Image, index: u32) u32 {
    return if (image.pathIsLooped(index)) image.pathLen(index) else image.pathLen(index) - 1;
}

pub fn getPositions(image: Image, index: u32) []math.Vec2 {
    const offset = image.getDataOffset(index);
    return image.data.items(.position)[offset .. offset + image.pathLen(index)];
}
pub fn getAngles(image: Image, index: u32) []f32 {
    const offset = image.getDataOffset(index);
    return image.data.items(.angle)[offset .. offset + image.pathAnglesLen(index)];
}
pub fn getPath(image: Image, index: u32) math.Path {
    return .{ .positions = image.getPositions(index), .angles = image.getAngles(index) };
}

pub fn addPoint(image: *Image, position: math.Vec2, style: PathStyle, name: PathName) !void {
    try image.data.append(image.allocator, .{ .position = position });
    try image.entries.append(image.allocator, .{ .len = 1, .looped = false, .style = style, .name = name });
}

pub fn appendPoint(image: *Image, index: u32, position: math.Vec2, angle: f32) !void {
    const offset = image.getDataOffset(index);
    image.data.items(.angle)[offset + image.pathLen(index) - 1] = angle;
    try image.data.insert(image.allocator, offset + image.pathLen(index), .{ .position = position });
    image.entries.items(.len)[index] += 1;
}

/// Add segment from last to first node
pub fn loopPath(image: *Image, index: u32, angle: f32) void {
    image.data.items(.angle)[image.getDataOffset(index) + image.pathLen(index) - 1] = angle;
    image.entries.items(.looped)[index] = true;
}

pub fn remove(image: *Image, index: u32) void {
    const offset = image.getDataOffset(index);
    const len = image.pathLen(index);
    std.mem.copy(image.data.items(.position)[offset..], image.data.items(.position)[offset + len ..]);
    std.mem.copy(image.data.items(.angle)[offset..], image.data.items(.angle)[offset + len ..]);
    image.data.shrinkRetainingCapacity(image.data.len - len);
    image.entries.orderedRemove(index);
}

pub fn reversePath(image: Image, index: u32) void {
    const positions = image.getPositions(index);
    const angles = image.getAngles(index);
    std.mem.reverse(math.Vec2, if (positions.len == angles.len) positions[0 .. positions.len - 1] else positions);
    std.mem.reverse(f32, angles);
    for (angles) |*angle|
        angle.* = -angle.*;
}

pub fn reorder(image: *Image, index: u32, new_index: u32) void {
    if (new_index < index) { // lower
        const from = image.getDataOffset(new_index);
        const to = image.getDataOffset(index) + image.pathLen(index);
        const amount = image.getDataOffset(index) - image.getDataOffset(new_index);
        std.mem.rotate(math.Vec2, image.data.items(.position)[from..to], amount);
        std.mem.rotate(f32, image.data.items(.angle)[from..to], amount);
    } else if (new_index > index) { // raise
        const from = image.getDataOffset(index);
        const to = image.getDataOffset(new_index) + image.pathLen(new_index);
        const amount = image.pathLen(index);
        std.mem.rotate(math.Vec2, image.data.items(.position)[from..to], amount);
        std.mem.rotate(f32, image.data.items(.angle)[from..to], amount);
    }
    const entry = image.entries.get(index);
    image.entries.orderedRemove(index);
    image.entries.insertAssumeCapacity(new_index, entry);
}

pub fn joinPaths(image: *Image, index_a: u32, index_b: u32, angle: f32) u32 {
    if (index_a == index_b) {
        image.loopPath(index_a, angle);
        return index_a;
    }
    const new_index = if (index_a < index_b) index_a else index_a - 1;
    image.reorder(index_b, new_index + 1);
    image.data.items(.angle)[image.getDataOffset(new_index) + image.pathLen(new_index) - 1] = angle;
    image.entries.items(.len)[new_index] += image.entries.items(.len)[new_index + 1];
    image.entries.orderedRemove(new_index + 1);
    return new_index;
}

/// Split segment in two
// pub fn splitSegment(image: *Image, index: u32, segment: u32, param: f32) !void {
//     const arc = image.getPath(index).getArc(segment);

//     try image.positions.insert(image.allocator, image.getPosOffset(index) + segment + 1, arc.point(param));
//     image.entries.items(.pos_len)[index] += 1;

//     image.positions.items[image.getAngOffset(index) + segment] = param * arc.angle;
//     try image.positions.insert(image.allocator, image.getAngOffset(index) + segment + 1, (1 - param) * arc.angle);
//     image.entries.items(.ang_len)[index] += 1;
// }

pub fn clear(image: *Image) void {
    image.data.shrinkRetainingCapacity(0);
    image.entries.shrinkRetainingCapacity(0);
}

pub fn clone(image: Image) !Image {
    var _drawing = image;
    return .{
        .allocator = image.allocator,
        .entries = try _drawing.entries.clone(image.allocator),
        .data = try _drawing.data.clone(image.allocator),
    };
}

const PathIterator = struct {
    image: *const Image,
    i: u32 = 0,
    offset: u32 = 0,

    pub fn next(it: *PathIterator) ?math.Path {
        if (it.i >= it.image.entries.len)
            return null;
        const path = math.Path{
            .positions = it.image.data.items(.position)[it.offset .. it.offset + it.image.pathLen(it.i)],
            .angles = it.image.data.items(.angle)[it.offset .. it.offset + it.image.pathAnglesLen(it.i)],
        };
        it.offset += it.image.pathLen(it.i);
        it.i += 1;
        return path;
    }
    pub fn getIndex(it: *PathIterator) u32 {
        return it.i - 1;
    }
    pub fn getStyle(it: *PathIterator) PathStyle {
        return it.image.entries.items(.style)[it.getIndex()];
    }
};
pub inline fn pathIterator(image: *const Image) PathIterator {
    return .{ .image = image };
}

const ReversePathIterator = struct {
    image: *const Image,
    i: u32,
    offset: u32,

    pub fn next(it: *ReversePathIterator) ?math.Path {
        if (it.i == 0)
            return null;
        it.i -= 1;
        it.offset -= it.image.pathLen(it.i);
        return .{
            .positions = it.image.data.items(.position)[it.offset .. it.offset + it.image.pathLen(it.i)],
            .angles = it.image.data.items(.angle)[it.offset .. it.offset + it.image.pathAnglesLen(it.i)],
        };
    }
    pub fn getIndex(it: *ReversePathIterator) u32 {
        return it.i;
    }
    pub fn getStyle(it: *ReversePathIterator) PathStyle {
        return it.image.entries.items(.style)[it.getIndex()];
    }
};
pub fn reversePathIterator(image: *const Image) ReversePathIterator {
    return .{ .image = image, .i = @intCast(u32, image.entries.len), .offset = @intCast(u32, image.data.len) };
}

pub fn draw(image: Image, buffer: *render.Buffer) !void {
    var it = image.pathIterator();
    while (it.next()) |path| {
        const style = it.getStyle();
        if (path.isLooped())
            try path.generate(buffer.generator(style.fill_color));
        try path.generate(style.stroke.generator(buffer.generator(style.stroke_color)));
    }
}
