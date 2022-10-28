const std = @import("std");
const render = @import("render.zig");
const vec2 = @import("linalg.zig").vec(f32, 2);
const mat2 = @import("linalg.zig").mat(f32, 2);

pub const Vertices = std.ArrayList(render.Vertex);
pub const Indices = std.ArrayList(u32);

pub fn genFanIndices(out_indices: *Indices, index: u32, len: u32) !void {
    var i: u32 = 0;
    while (i < len - 2) : (i += 1) {
        try out_indices.appendSlice(&.{ index, index + i + 1, index + i + 2 });
    }
}

pub fn genStripeIndices(out_indices: *Indices, index: u32, len: u32) !void {
    var i: u32 = 0;
    while (i < len - 2) : (i += 1) {
        try out_indices.appendSlice(&.{ index + i, index + i + 1, index + i + 2 });
    }
}

pub fn arcSeg(pos_a: [2]f32, pos_b: [2]f32, angle: f32, seg_angle: f32) [2]f32 {
    std.debug.assert(angle != 0);
    const scale = @sin(seg_angle) / @sin(angle);
    const rotation = mat2.rotate(0, 1, seg_angle - angle);
    return vec2.add(pos_a, mat2.multiplyV(rotation, vec2.multiplyS(vec2.subtract(pos_b, pos_a), scale)));
}

pub fn genArcVertices(
    out_vertices: *Vertices,
    pos_a: [2]f32,
    pos_b: [2]f32,
    angle: f32,
    step_angle: f32,
    color: [4]u8,
) !void {
    std.debug.assert(step_angle > 0);
    try out_vertices.append(.{ .pos = pos_a, .color = color }); // first seg is outside of the loop because angle can be 0
    var seg_angle = step_angle;
    while (seg_angle < @fabs(angle)) : (seg_angle += step_angle) {
        try out_vertices.append(.{ .pos = arcSeg(pos_a, pos_b, angle, seg_angle * std.math.sign(angle)), .color = color });
    }
}

pub inline fn normal(vec: [2]f32) [2]f32 {
    return .{ -vec[1], vec[0] };
}

pub fn genCircle(
    out_vertices: *Vertices,
    out_indices: *Indices,
    center: [2]f32,
    radius: f32,
    step_angle: f32,
    color: [4]u8,
) !void {
    const index = @intCast(u32, out_vertices.items.len);
    const pos_a = vec2.add(center, .{ -radius, 0 });
    const pos_b = vec2.add(center, .{ radius, 0 });
    try genArcVertices(out_vertices, pos_a, pos_b, std.math.pi / 2.0, step_angle, color);
    try genArcVertices(out_vertices, pos_b, pos_a, std.math.pi / 2.0, step_angle, color);
    try genFanIndices(out_indices, index, @intCast(u32, out_vertices.items.len) - index);
}

pub const Stroke = struct {
    width: f32 = 0,
    color: [4]u8 = .{ 0, 0, 0, 1 },
    cap: CapStyle = .none,
    seg_angle: f32 = std.math.pi / 16.0,
    cap_seg_angle: f32 = std.math.pi / 8.0,

    pub const CapStyle = enum {
        none,
        rounded,
        sharp,
    };

    pub fn genCap(stroke: Stroke, out_vertices: *Vertices, out_indices: *Indices, pos: [2]f32, pos_before: ?[2]f32, pos_after: ?[2]f32) !void {
        switch (stroke.cap) {
            .none => {},
            .rounded => {
                try genCircle(out_vertices, out_indices, pos, stroke.width / 2, stroke.cap_seg_angle, stroke.color); // TODO: could be optimized
            },
            .sharp => { // TODO
                _ = pos_before;
                _ = pos_after;
            },
        }
    }

    pub fn genArc(stroke: Stroke, out_vertices: *Vertices, out_indices: *Indices, pos_a: [2]f32, pos_b: [2]f32, angle: f32) !void {
        const direction = vec2.multiplyS(vec2.normalize(vec2.subtract(pos_b, pos_a)), stroke.width / 2);
        const direction_a = mat2.multiplyV(mat2.rotate(0, 1, -angle), direction);
        const direction_b = mat2.multiplyV(mat2.rotate(0, 1, angle), vec2.negate(direction));

        const top_index = @intCast(u32, out_vertices.items.len);
        try genArcVertices(out_vertices, vec2.add(pos_a, normal(direction_a)), vec2.subtract(pos_b, normal(direction_b)), angle, stroke.seg_angle, stroke.color);
        try out_vertices.append(.{ .pos = vec2.subtract(pos_b, normal(direction_b)), .color = stroke.color });

        const bot_index = @intCast(u32, out_vertices.items.len);
        try genArcVertices(out_vertices, vec2.subtract(pos_a, normal(direction_a)), vec2.add(pos_b, normal(direction_b)), angle, stroke.seg_angle, stroke.color);
        try out_vertices.append(.{ .pos = vec2.add(pos_b, normal(direction_b)), .color = stroke.color });

        const len = @floatToInt(u32, @fabs(angle / stroke.seg_angle)) + 1;
        var i: u32 = 0;
        while (i < len) : (i += 1) {
            try out_indices.appendSlice(&.{
                top_index + i,
                bot_index + i,
                top_index + 1 + i,
                bot_index + i,
                top_index + 1 + i,
                bot_index + 1 + i,
            });
        }
    }
};

pub const Path = struct {
    positions: []const [2]f32,
    angles: []const f32,
    stroke: Stroke,

    pub fn gen(path: Path, out_vertices: *Vertices, out_indices: *Indices) !void {
        var i: u32 = 0;
        while (i < path.len()) : (i += 1) {
            try path.stroke.genCap(
                out_vertices,
                out_indices,
                path.getPos(i),
                if (path.prevIndex(i)) |j| path.getPos(j) else null,
                if (path.nextIndex(i)) |j| path.getPos(j) else null,
            );
            if (path.nextIndex(i)) |j| try path.stroke.genArc(
                out_vertices,
                out_indices,
                path.getPos(i),
                path.getPos(j),
                path.getAngleFrom(i),
            );
        }
    }

    pub inline fn isLooped(path: Path) bool {
        return path.positions.len == path.angles.len;
    }

    // Returns number of vertices
    pub inline fn len(path: Path) u32 {
        return @intCast(u32, path.positions.len);
    }

    pub inline fn getPos(path: Path, index: u32) [2]f32 {
        return path.positions[index];
    }

    pub inline fn getAngleTo(path: Path, index: u32) f32 {
        return path.angles[path.prevIndex(index) orelse unreachable];
    }

    pub inline fn getAngleFrom(path: Path, index: u32) f32 {
        return path.angles[index];
    }

    pub inline fn nextIndex(path: Path, index: u32) ?u32 {
        if (index < path.len() - 1) return index + 1;
        if (path.isLooped()) return 0;
        return null;
    }

    pub inline fn prevIndex(path: Path, index: u32) ?u32 {
        if (index > 0) return index - 1;
        if (path.isLooped()) return path.len() - 1;
        return null;
    }
};

// pub fn genStrokePath(out_vertices: *Vertices, out_indices: *Indices, positions: []const [2]f32, )
