const std = @import("std");
const render = @import("render.zig");
const vec2 = @import("linalg.zig").vec(2, f32);
const mat2 = @import("linalg.zig").mat(2, f32);

pub const Vec2 = vec2.Vector;

pub inline fn normal(vec: Vec2) Vec2 {
    return .{ -vec[1], vec[0] };
}

pub fn angleBetween(dir_a: Vec2, dir_b: Vec2) f32 {
    return std.math.atan2(f32, dir_a[0] * dir_b[1] - dir_a[1] * dir_b[0], dir_a[0] * dir_b[0] + dir_a[1] * dir_b[1]);
}

/// Solves equation pos_a + p * dir_a = pos_b + q * dir_b, returns p
pub fn linesIntersection(pos_a: Vec2, dir_a: Vec2, pos_b: Vec2, dir_b: Vec2) f32 {
    const pos = pos_b - pos_a;
    return (pos[0] * dir_b[1] - pos[1] * dir_b[0]) / (dir_a[0] * dir_b[1] - dir_a[1] * dir_b[0]);
}

pub const Arc = struct {
    pos_a: Vec2,
    pos_b: Vec2,
    angle: f32 = 0,

    /// Get point on arc, param is in ragnge from 0 to 1
    pub fn point(arc: Arc, param: f32) Vec2 {
        const scale = if (arc.angle == 0) param else @sin(arc.angle * param) / @sin(arc.angle);
        const rotation = mat2.rotate(0, 1, arc.angle * (1 - param));
        return arc.pos_a + mat2.multVec(rotation, (arc.pos_b - arc.pos_a) * vec2.splat(scale));
    }

    /// Get underlying circle (undefined for straight lines)
    pub fn toCircle(arc: Arc) Circle {
        std.debug.assert(arc.angle != 0);
        const line_center = (arc.pos_a + arc.pos_b) / vec2.splat(2);
        const line_normal = normal(line_center - arc.pos_a);
        return .{
            .pos = line_center - line_normal / vec2.splat(@tan(arc.angle)),
            .radius = vec2.abs(line_normal) / @sin(@fabs(arc.angle)),
        };
    }

    pub fn boundingBox(arc: Arc) [2]Vec2 {
        var min_pos = @min(arc.pos_a, arc.pos_b);
        var max_pos = @max(arc.pos_a, arc.pos_b);
        if (arc.angle != 0) {
            const circle = arc.toCircle();
            for ([4]Vec2{ .{ 0, 1 }, .{ 0, -1 }, .{ 1, 0 }, .{ -1, 0 } }) |direction| {
                const pos = circle.pos + direction * vec2.splat(circle.radius);
                if (std.math.sign(arc.angleOnPoint(pos)) == std.math.sign(arc.angle)) {
                    min_pos = @min(min_pos, pos);
                    max_pos = @max(max_pos, pos);
                }
            }
        }
        return .{ min_pos, max_pos };
    }

    /// Get direction from pos_a
    pub fn dirA(arc: Arc) Vec2 {
        const line_dir = vec2.normalize(arc.pos_b - arc.pos_a);
        return mat2.multVec(mat2.rotate(0, 1, arc.angle), line_dir);
    }

    /// Get direction from pos_b
    pub fn dirB(arc: Arc) Vec2 {
        const line_dir = vec2.normalize(arc.pos_a - arc.pos_b);
        return mat2.multVec(mat2.rotate(0, 1, -arc.angle), line_dir);
    }

    /// Get angle of arc that contains given point, angle of given arc is ignored
    pub fn angleOnPoint(arc: Arc, point_pos: Vec2) f32 {
        return -angleBetween(arc.pos_a - point_pos, point_pos - arc.pos_b);
    }

    /// Get param of arc that contains given point, angle of given arc is ignored
    pub fn paramOnPoint(arc: Arc, point_pos: Vec2) f32 {
        const dir_a = vec2.normalize(arc.pos_a - point_pos);
        const dir_b = vec2.normalize(arc.pos_b - point_pos);
        return linesIntersection(arc.pos_a, arc.pos_b - arc.pos_a, point_pos, dir_a + dir_b);
    }
};

pub const Path = struct {
    positions: []const Vec2,
    angles: []const f32,

    pub fn gen(path: Path, color: [4]u8, buffer: *render.Buffer) !void {
        std.debug.assert(path.isLooped());
        try buffer.append(path, color);
    }

    pub inline fn isLooped(path: Path) bool {
        return path.positions.len == path.angles.len;
    }

    // Returns number of vertices
    pub inline fn len(path: Path) u32 {
        return @intCast(u32, path.positions.len);
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

    pub inline fn pos(path: Path, index: u32) Vec2 {
        return path.positions[index];
    }

    pub inline fn angleFrom(path: Path, index: u32) ?f32 {
        return if (index < path.angles.len) path.angles[index] else null;
    }

    pub inline fn angleTo(path: Path, index: u32) ?f32 {
        return if (path.prevIndex(index)) |prev_index| path.angles[prev_index] else null;
    }

    pub inline fn arcFrom(path: Path, index: u32) ?Arc {
        return if (path.nextIndex(index)) |next_index| .{
            .pos_a = path.pos(index),
            .pos_b = path.pos(next_index),
            .angle = path.angleFrom(index).?,
        } else null;
    }

    pub inline fn arcTo(path: Path, index: u32) ?Arc {
        return if (path.prevIndex(index)) |prev_index| .{
            .pos_a = path.pos(prev_index),
            .pos_b = path.pos(index),
            .angle = path.angleTo(index).?,
        } else null;
    }

    pub fn containsPoint(path: Path, point_pos: Vec2) bool {
        std.debug.assert(path.isLooped());
        var inside = false;
        var index: u32 = 0;
        while (index < path.len()) : (index += 1) {
            const arc = path.arcFrom(index).?;

            const crossing_line = (point_pos[1] < arc.pos_a[1]) != (point_pos[1] < arc.pos_b[1]) and
                linesIntersection(point_pos, .{ 1, 0 }, arc.pos_a, arc.pos_b - arc.pos_a) > 0;
            inside = inside != crossing_line;

            const point_angle = arc.angleOnPoint(point_pos);
            const in_arc = std.math.sign(point_angle) == std.math.sign(arc.angle) and @fabs(point_angle) < @fabs(arc.angle);
            inside = inside != in_arc;
        }
        return inside;
    }
};

pub const Circle = struct {
    pos: Vec2,
    radius: f32,

    pub fn gen(circle: Circle, color: [4]u8, buffer: *render.Buffer) !void {
        try buffer.append(.{ .positions = &.{
            circle.pos + Vec2{ -circle.radius, 0 },
            circle.pos + Vec2{ circle.radius, 0 },
        }, .angles = &.{
            std.math.pi / 2.0,
            std.math.pi / 2.0,
        } }, color);
    }
};

pub const Stroke = struct {
    width: f32,
    cap: CapStyle,

    pub const CapStyle = enum {
        none,
        round,
        bevel,
        miter,
    };

    // Generate cap from two directions (normalized, facing out from the cap)
    pub fn genCap(stroke: Stroke, pos: Vec2, dir_a: Vec2, dir_b: Vec2, color: [4]u8, buffer: *render.Buffer) !void {
        if (vec2.dot(dir_a, dir_b) == 0) return; // directions are opposite, no cap is needed

        const dir = vec2.normalize(dir_a + dir_b) * vec2.splat(-stroke.width);
        const sign: f32 = if (vec2.dot(normal(dir_a), dir_b) >= 0) 1 else -1;
        const normal_a = normal(dir_a) * vec2.splat(-sign * stroke.width);
        const normal_b = normal(dir_b) * vec2.splat(sign * stroke.width);

        switch (stroke.cap) {
            .none => {},
            .round => {
                try buffer.append(.{
                    .positions = &.{ pos, pos + normal_a, pos + normal_b },
                    .angles = &.{ 0, Arc.angleOnPoint(.{ .pos_a = normal_a, .pos_b = normal_b }, dir), 0 },
                }, color);
            },
            .bevel => {
                try buffer.append(.{
                    .positions = &.{ pos, pos + normal_a, pos + normal_b },
                    .angles = &.{ 0, 0, 0 },
                }, color);
            },
            .miter => {
                // const tip_dist = (normal_a[0] * dir_a[1] - normal_a[1] * dir_a[0]) / (dir[0] * dir_a[1] - dir[1] * dir_a[0]);
                const tip_dist = linesIntersection(.{ 0, 0 }, dir, normal_a, dir_a);
                if (tip_dist > 0 and tip_dist < 8) {
                    try buffer.append(.{
                        .positions = &.{ pos, pos + normal_a, pos + dir * vec2.splat(tip_dist), pos + normal_b },
                        .angles = &.{ 0, 0, 0, 0 },
                    }, color);
                } else {
                    try buffer.append(.{
                        .positions = &.{
                            pos,
                            pos + normal_a,
                            pos + normal_a - dir_a * vec2.splat(stroke.width),
                            pos + normal_b - dir_b * vec2.splat(stroke.width),
                            pos + normal_b,
                        },
                        .angles = &.{ 0, 0, 0, 0, 0 },
                    }, color);
                }
            },
        }
    }

    pub fn genArc(stroke: Stroke, arc: Arc, color: [4]u8, buffer: *render.Buffer) !void {
        const normal_a = normal(arc.dirA()) * vec2.splat(stroke.width);
        const normal_b = normal(arc.dirB()) * vec2.splat(stroke.width);
        try buffer.append(.{
            .positions = &.{ arc.pos_a + normal_a, arc.pos_b - normal_b, arc.pos_b + normal_b, arc.pos_a - normal_a },
            .angles = &.{ arc.angle, 0, -arc.angle, 0 },
        }, color);
    }

    pub fn genPath(stroke: Stroke, path: Path, color: [4]u8, buffer: *render.Buffer) !void {
        var index: u32 = 0;
        while (index < path.len()) : (index += 1) {
            if (path.arcFrom(index)) |arc_from| {
                try stroke.genArc(arc_from, color, buffer);
                if (path.arcTo(index)) |arc_to| {
                    try stroke.genCap(path.pos(index), arc_from.dirA(), arc_to.dirB(), color, buffer);
                } else {
                    try stroke.genCap(path.pos(index), arc_from.dirA(), arc_from.dirA(), color, buffer);
                }
            } else if (path.arcTo(index)) |arc_to| {
                try stroke.genCap(path.pos(index), arc_to.dirB(), arc_to.dirB(), color, buffer);
            } else {
                try stroke.genCap(path.pos(index), .{ 1, 0 }, .{ 1, 0 }, color, buffer);
                try stroke.genCap(path.pos(index), .{ -1, 0 }, .{ -1, 0 }, color, buffer);
            }
        }
    }
};
