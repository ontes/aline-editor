const std = @import("std");
const render = @import("../render.zig");
const geometry = @import("../geometry.zig");

pub const Style = struct {
    stroke: geometry.Stroke,
    fill_color: render.Color,
    stroke_color: render.Color,

    pub fn isFilled(style: Style) bool {
        return style.fill_color[3] > 0;
    }
};

const Drawing = @This();

allocator: std.mem.Allocator,
entries: std.MultiArrayList(struct { len: u32, is_looped: bool, style: Style }) = .{},
data: std.MultiArrayList(struct { position: geometry.Vec2, angle: f32 = 0 }) = .{},

pub inline fn init(allocator: std.mem.Allocator) Drawing {
    return .{ .allocator = allocator };
}

pub fn deinit(drawing: *Drawing) void {
    drawing.entries.deinit(drawing.allocator);
    drawing.data.deinit(drawing.allocator);
}

fn getOffset(drawing: Drawing, index: u32) u32 {
    var offset: u32 = 0;
    for (drawing.entries.items(.len)[0..index]) |len|
        offset += len;
    return offset;
}
pub fn getLen(drawing: Drawing, index: u32) u32 {
    return drawing.entries.items(.len)[index];
}
fn getAnglesLen(drawing: Drawing, index: u32) u32 {
    return if (drawing.entries.items(.is_looped)[index]) drawing.getLen(index) else drawing.getLen(index) - 1;
}

pub fn getPositions(drawing: Drawing, index: u32) []geometry.Vec2 {
    const offset = drawing.getOffset(index);
    return drawing.data.items(.position)[offset .. offset + drawing.getLen(index)];
}
pub fn getAngles(drawing: Drawing, index: u32) []f32 {
    const offset = drawing.getOffset(index);
    return drawing.data.items(.angle)[offset .. offset + drawing.getAnglesLen(index)];
}
pub fn getPath(drawing: Drawing, index: u32) geometry.Path {
    return .{ .positions = drawing.getPositions(index), .angles = drawing.getAngles(index) };
}

pub fn addPoint(drawing: *Drawing, position: geometry.Vec2, style: Style) !void {
    try drawing.data.append(drawing.allocator, .{ .position = position });
    try drawing.entries.append(drawing.allocator, .{ .len = 1, .is_looped = false, .style = style });
}

pub fn appendPoint(drawing: *Drawing, index: u32, position: geometry.Vec2, angle: f32) !void {
    const offset = drawing.getOffset(index);
    drawing.data.items(.angle)[offset + drawing.getLen(index) - 1] = angle;
    try drawing.data.insert(drawing.allocator, offset + drawing.getLen(index), .{ .position = position });
    drawing.entries.items(.len)[index] += 1;
}

/// Add segment from last to first node
pub fn loopPath(drawing: *Drawing, index: u32, angle: f32) void {
    drawing.data.items(.angle)[drawing.getOffset(index) + drawing.getLen(index) - 1] = angle;
    drawing.entries.items(.is_looped)[index] = true;
}

pub fn remove(drawing: *Drawing, index: u32) void {
    const offset = drawing.getOffset(index);
    const len = drawing.getLen(index);
    std.mem.copy(drawing.data.items(.position)[offset..], drawing.data.items(.position)[offset + len ..]);
    std.mem.copy(drawing.data.items(.angle)[offset..], drawing.data.items(.angle)[offset + len ..]);
    drawing.data.shrinkRetainingCapacity(drawing.data.len - len);
    drawing.entries.orderedRemove(index);
}

pub fn reversePath(drawing: Drawing, index: u32) void {
    const positions = drawing.getPositions(index);
    const angles = drawing.getAngles(index);
    std.mem.reverse(geometry.Vec2, if (positions.len == angles.len) positions[0 .. positions.len - 1] else positions);
    std.mem.reverse(f32, angles);
    for (angles) |*angle|
        angle.* = -angle.*;
}

pub fn joinPaths(drawing: *Drawing, index_a: u32, index_b: u32, angle: f32) void {
    drawing.data.items(.angle)[drawing.getOffset(index_a) + drawing.getLen(index_a) - 1] = angle;
    if (index_a < index_b) {
        const from = drawing.getOffset(index_a) + drawing.getLen(index_a);
        const to = drawing.getOffset(index_b) + drawing.getLen(index_b);
        const amount = to - from - drawing.getLen(index_b);
        std.mem.rotate(geometry.Vec2, drawing.data.items(.position)[from..to], amount);
        std.mem.rotate(f32, drawing.data.items(.angle)[from..to], amount);
    } else {
        const from = drawing.getOffset(index_b);
        const to = drawing.getOffset(index_a) + drawing.getLen(index_a);
        const amount = drawing.getLen(index_b);
        std.mem.rotate(geometry.Vec2, drawing.data.items(.position)[from..to], amount);
        std.mem.rotate(f32, drawing.data.items(.angle)[from..to], amount);
    }
    drawing.entries.items(.len)[index_a] += drawing.entries.items(.len)[index_b];
    drawing.entries.orderedRemove(index_b);
}

/// Split segment in two
// pub fn splitSegment(drawing: *Drawing, index: u32, segment: u32, param: f32) !void {
//     const arc = drawing.getPath(index).getArc(segment);

//     try drawing.positions.insert(drawing.allocator, drawing.getPosOffset(index) + segment + 1, arc.point(param));
//     drawing.entries.items(.pos_len)[index] += 1;

//     drawing.positions.items[drawing.getAngOffset(index) + segment] = param * arc.angle;
//     try drawing.positions.insert(drawing.allocator, drawing.getAngOffset(index) + segment + 1, (1 - param) * arc.angle);
//     drawing.entries.items(.ang_len)[index] += 1;
// }

pub fn clear(drawing: *Drawing) void {
    drawing.data.shrinkRetainingCapacity(0);
    drawing.entries.shrinkRetainingCapacity(0);
}

pub fn clone(drawing: Drawing) !Drawing {
    var _drawing = drawing;
    return .{
        .allocator = drawing.allocator,
        .entries = try _drawing.entries.clone(drawing.allocator),
        .data = try _drawing.data.clone(drawing.allocator),
    };
}

const PathIterator = struct {
    drawing: *const Drawing,
    i: u32 = 0,
    offset: u32 = 0,

    pub fn next(it: *PathIterator) ?geometry.Path {
        if (it.i >= it.drawing.entries.len)
            return null;
        const path = geometry.Path{
            .positions = it.drawing.data.items(.position)[it.offset .. it.offset + it.drawing.getLen(it.i)],
            .angles = it.drawing.data.items(.angle)[it.offset .. it.offset + it.drawing.getAnglesLen(it.i)],
        };
        it.offset += it.drawing.getLen(it.i);
        it.i += 1;
        return path;
    }
    pub fn getIndex(it: *PathIterator) u32 {
        return it.i - 1;
    }
    pub fn getStyle(it: *PathIterator) Style {
        return it.drawing.entries.items(.style)[it.getIndex()];
    }
};
pub inline fn pathIterator(drawing: *const Drawing) PathIterator {
    return .{ .drawing = drawing };
}

const ReversePathIterator = struct {
    drawing: *const Drawing,
    i: u32,
    offset: u32,

    pub fn next(it: *ReversePathIterator) ?geometry.Path {
        if (it.i == 0)
            return null;
        it.i -= 1;
        it.offset -= it.drawing.getLen(it.i);
        return .{
            .positions = it.drawing.data.items(.position)[it.offset .. it.offset + it.drawing.getLen(it.i)],
            .angles = it.drawing.data.items(.angle)[it.offset .. it.offset + it.drawing.getAnglesLen(it.i)],
        };
    }
    pub fn getIndex(it: *ReversePathIterator) u32 {
        return it.i;
    }
    pub fn getStyle(it: *ReversePathIterator) Style {
        return it.drawing.entries.items(.style)[it.getIndex()];
    }
};
pub fn reversePathIterator(drawing: *const Drawing) ReversePathIterator {
    return .{ .drawing = drawing, .i = @intCast(u32, drawing.entries.len), .offset = @intCast(u32, drawing.data.len) };
}

pub fn draw(drawing: Drawing, buffer: *render.Buffer) !void {
    var it = drawing.pathIterator();
    while (it.next()) |path| {
        const style = it.getStyle();
        if (path.isLooped())
            try buffer.append(path, style.fill_color);
        try style.stroke.drawPath(path, style.stroke_color, buffer);
    }
}
