const std = @import("std");
const render = @import("render.zig");
const vec2 = @import("linalg.zig").vec(f32, 2);
const mat2 = @import("linalg.zig").mat(f32, 2);

pub inline fn normal(vec: [2]f32) [2]f32 {
    return .{ -vec[1], vec[0] };
}

pub const Arc = struct {
    pos_a: [2]f32,
    pos_b: [2]f32,
    angle: f32,

    /// Get point on arc by a given angle (undefined for straight lines)
    pub fn point(arc: Arc, point_angle: f32) [2]f32 {
        std.debug.assert(arc.angle != 0);
        const scale = @sin(point_angle) / @sin(arc.angle);
        const rotation = mat2.rotate(0, 1, point_angle - arc.angle);
        return vec2.add(arc.pos_a, mat2.multiplyV(rotation, vec2.multiplyS(vec2.subtract(arc.pos_b, arc.pos_a), scale)));
    }

    /// Get underlying circle (undefined for straight lines)
    pub fn toCircle(arc: Arc) Circle {
        std.debug.assert(arc.angle != 0);
        const line_center = vec2.divideS(vec2.add(arc.pos_a, arc.pos_b), 2);
        const line_normal = normal(vec2.subtract(line_center, arc.pos_a));
        return .{
            .pos = vec2.add(line_center, vec2.divideS(line_normal, @tan(arc.angle))),
            .radius = @fabs(vec2.abs(line_normal) / @sin(arc.angle)),
        };
    }

    pub fn boundingBox(arc: Arc) [2][2]f32 {
        var min_pos = vec2.min(arc.pos_a, arc.pos_b);
        var max_pos = vec2.max(arc.pos_a, arc.pos_b);
        if (arc.angle != 0) {
            const circle = arc.toCircle();
            for ([4][2]f32{ .{ 0, 1 }, .{ 0, -1 }, .{ 1, 0 }, .{ -1, 0 } }) |direction| {
                const pos = vec2.add(circle.pos, vec2.multiplyS(direction, circle.radius));
                if (std.math.sign(arcAngleFromPoint(arc.pos_a, arc.pos_b, pos)) == std.math.sign(arc.angle)) {
                    min_pos = vec2.min(min_pos, pos);
                    max_pos = vec2.max(max_pos, pos);
                }
            }
        }
        return .{ min_pos, max_pos };
    }

    pub fn dirA(arc: Arc) [2]f32 {
        const line_dir = vec2.normalize(vec2.subtract(arc.pos_b, arc.pos_a));
        return mat2.multiplyV(mat2.rotate(0, 1, -arc.angle), line_dir);
    }

    pub fn dirB(arc: Arc) [2]f32 {
        const line_dir = vec2.normalize(vec2.subtract(arc.pos_a, arc.pos_b));
        return mat2.multiplyV(mat2.rotate(0, 1, arc.angle), line_dir);
    }
};

pub fn angleBetween(dir_a: [2]f32, dir_b: [2]f32) f32 {
    return std.math.atan2(f32, dir_a[0] * dir_b[1] - dir_a[1] * dir_b[0], dir_a[0] * dir_b[0] + dir_a[1] * dir_b[1]);
}

/// Get angle of an arc that contains given point.
pub fn arcAngleFromPoint(pos_a: [2]f32, pos_b: [2]f32, point_pos: [2]f32) f32 {
    return angleBetween(vec2.subtract(pos_a, point_pos), vec2.subtract(point_pos, pos_b));
}

pub const Path = struct {
    positions: []const [2]f32,
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

    pub inline fn getPos(path: Path, index: u32) [2]f32 {
        return path.positions[index];
    }

    pub inline fn getAngleFrom(path: Path, index: u32) ?f32 {
        return if (index < path.angles.len) path.angles[index] else null;
    }

    pub inline fn getAngleTo(path: Path, index: u32) ?f32 {
        return if (path.prevIndex(index)) |prev_index| path.angles[prev_index] else null;
    }

    pub inline fn getArcFrom(path: Path, index: u32) ?Arc {
        return if (path.nextIndex(index)) |next_index| .{
            .pos_a = path.getPos(index),
            .pos_b = path.getPos(next_index),
            .angle = path.getAngleFrom(index).?,
        } else null;
    }

    pub inline fn getArcTo(path: Path, index: u32) ?Arc {
        return if (path.prevIndex(index)) |prev_index| .{
            .pos_a = path.getPos(prev_index),
            .pos_b = path.getPos(index),
            .angle = path.getAngleTo(index).?,
        } else null;
    }

    pub fn isInside(path: Path, pos: [2]f32) bool {
        std.debug.assert(path.isLooped());
        var inside = false;
        var index: u32 = 0;
        while (index < path.len()) : (index += 1) {
            inside = inside != isCrossingLine(pos, path.getPos(index), path.getPos(path.nextIndex(index).?));
            inside = inside != isInArc(pos, path.getArcFrom(index).?);
        }
        return inside;
    }

    fn isCrossingLine(pos: [2]f32, pos_a: [2]f32, pos_b: [2]f32) bool {
        return ((pos[1] < pos_a[1]) != (pos[1] < pos_b[1])) and
            (pos[0] < (pos_b[0] - pos_a[0]) / (pos_b[1] - pos_a[1]) * (pos[1] - pos_a[1]) + pos_a[0]);
    }

    fn isInArc(pos: [2]f32, arc: Arc) bool {
        const pos_angle = arcAngleFromPoint(arc.pos_a, arc.pos_b, pos);
        return std.math.sign(pos_angle) == std.math.sign(arc.angle) and @fabs(pos_angle) < @fabs(arc.angle);
    }
};

pub const Circle = struct {
    pos: [2]f32,
    radius: f32,

    pub fn gen(circle: Circle, color: [4]u8, buffer: *render.Buffer) !void {
        try buffer.append(.{ .positions = &.{
            vec2.add(circle.pos, .{ -circle.radius, 0 }),
            vec2.add(circle.pos, .{ circle.radius, 0 }),
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
    pub fn genCap(stroke: Stroke, pos: [2]f32, dir_a: [2]f32, dir_b: [2]f32, color: [4]u8, buffer: *render.Buffer) !void {
        if (vec2.dot(dir_a, dir_b) == 0) return; // directions are opposite, no cap is needed

        const dir = vec2.multiplyS(vec2.normalize(vec2.add(dir_a, dir_b)), -stroke.width);
        const sign: f32 = if (vec2.dot(normal(dir_a), dir_b) >= 0) 1 else -1;
        const normal_a = vec2.multiplyS(normal(dir_a), -sign * stroke.width);
        const normal_b = vec2.multiplyS(normal(dir_b), sign * stroke.width);

        switch (stroke.cap) {
            .none => {},
            .round => {
                try buffer.append(.{ .positions = &.{
                    pos,
                    vec2.add(pos, normal_a),
                    vec2.add(pos, normal_b),
                }, .angles = &.{ 0, arcAngleFromPoint(normal_a, normal_b, dir), 0 } }, color);
            },
            .bevel => {
                try buffer.append(.{ .positions = &.{
                    pos,
                    vec2.add(pos, normal_a),
                    vec2.add(pos, normal_b),
                }, .angles = &.{ 0, 0, 0 } }, color);
            },
            .miter => {
                const tip_dist = (normal_a[0] * dir_a[1] - normal_a[1] * dir_a[0]) / (dir[0] * dir_a[1] - dir[1] * dir_a[0]);
                if (tip_dist > 0 and tip_dist < 8) {
                    try buffer.append(.{ .positions = &.{
                        pos,
                        vec2.add(pos, normal_a),
                        vec2.add(pos, vec2.multiplyS(dir, tip_dist)),
                        vec2.add(pos, normal_b),
                    }, .angles = &.{ 0, 0, 0, 0 } }, color);
                } else {
                    try buffer.append(.{ .positions = &.{
                        pos,
                        vec2.add(pos, normal_a),
                        vec2.add(vec2.add(pos, normal_a), vec2.multiplyS(dir_a, -stroke.width)),
                        vec2.add(vec2.add(pos, normal_b), vec2.multiplyS(dir_b, -stroke.width)),
                        vec2.add(pos, normal_b),
                    }, .angles = &.{ 0, 0, 0, 0, 0 } }, color);
                }
            },
        }
    }

    pub fn genArc(stroke: Stroke, arc: Arc, color: [4]u8, buffer: *render.Buffer) !void {
        const normal_a = vec2.multiplyS(normal(arc.dirA()), stroke.width);
        const normal_b = vec2.multiplyS(normal(arc.dirB()), stroke.width);
        try buffer.append(.{ .positions = &.{
            vec2.add(arc.pos_a, normal_a),
            vec2.subtract(arc.pos_b, normal_b),
            vec2.add(arc.pos_b, normal_b),
            vec2.subtract(arc.pos_a, normal_a),
        }, .angles = &.{ arc.angle, 0, -arc.angle, 0 } }, color);
    }

    pub fn genPath(stroke: Stroke, path: Path, color: [4]u8, buffer: *render.Buffer) !void {
        var index: u32 = 0;
        while (index < path.len()) : (index += 1) {
            if (path.getArcFrom(index)) |arc_from| {
                try stroke.genArc(arc_from, color, buffer);
                if (path.getArcTo(index)) |arc_to| {
                    try stroke.genCap(path.getPos(index), arc_from.dirA(), arc_to.dirB(), color, buffer);
                } else {
                    try stroke.genCap(path.getPos(index), arc_from.dirA(), arc_from.dirA(), color, buffer);
                }
            } else if (path.getArcTo(index)) |arc_to| {
                try stroke.genCap(path.getPos(index), arc_to.dirB(), arc_to.dirB(), color, buffer);
            } else {
                try stroke.genCap(path.getPos(index), .{ 1, 0 }, .{ 1, 0 }, color, buffer);
                try stroke.genCap(path.getPos(index), .{ -1, 0 }, .{ -1, 0 }, color, buffer);
            }
        }
    }
};
