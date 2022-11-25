const std = @import("std");
const render = @import("render.zig");
const vec2 = @import("linalg.zig").vec(2, f32);
const mat2 = @import("linalg.zig").mat(2, f32);

pub const Vec2 = vec2.Vector;

pub fn normal(vec: Vec2) Vec2 {
    return .{ -vec[1], vec[0] };
}

pub fn rotate(vec: Vec2, angle: f32) Vec2 {
    return mat2.multVec(mat2.rotate(0, 1, angle), vec);
}

pub fn angleBetween(dir_a: Vec2, dir_b: Vec2) f32 {
    return std.math.atan2(f32, dir_a[0] * dir_b[1] - dir_a[1] * dir_b[0], dir_a[0] * dir_b[0] + dir_a[1] * dir_b[1]);
}

pub fn oppositeAngle(angle: f32) f32 {
    return if (angle > 0) std.math.pi - angle else -std.math.pi - angle;
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
        const angle = arc.angle * (1 - param);
        return arc.pos_a + rotate(arc.pos_b - arc.pos_a, angle) * vec2.splat(scale);
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
        return rotate(arc.pos_b - arc.pos_a, arc.angle);
    }

    /// Get direction from pos_b
    pub fn dirB(arc: Arc) Vec2 {
        return rotate(arc.pos_a - arc.pos_b, -arc.angle);
    }

    pub fn height(arc: Arc) f32 {
        return vec2.abs(arc.pos_a - arc.pos_b) * @tan(arc.angle / 2) / 2;
    }

    /// Get angle of arc that contains given point (angle of given arc is ignored)
    pub fn angleOnPoint(arc: Arc, point_pos: Vec2) f32 {
        return oppositeAngle(angleBetween(arc.pos_a - point_pos, arc.pos_b - point_pos));
    }
};

pub const Path = struct {
    positions: []const Vec2,
    angles: []const f32,

    pub inline fn len(path: Path) u32 {
        return @intCast(u32, path.positions.len);
    }
    pub fn isLooped(path: Path) bool {
        return path.positions.len == path.angles.len;
    }
    pub fn next(path: Path, node: u32) u32 {
        return (node + 1) % path.len();
    }
    pub fn prev(path: Path, node: u32) u32 {
        return (node + path.len() - 1) % path.len();
    }

    pub fn getArc(path: Path, index: u32) Arc {
        return .{
            .pos_a = path.positions[index],
            .pos_b = path.positions[path.next(index)],
            .angle = path.angles[index],
        };
    }

    pub fn containsPoint(path: Path, point_pos: Vec2) bool {
        std.debug.assert(path.isLooped());
        var inside = false;
        var index: u32 = 0;
        while (index < path.len()) : (index += 1) {
            const arc = path.getArc(index);
            if ((point_pos[1] < arc.pos_a[1]) != (point_pos[1] < arc.pos_b[1]) and
                linesIntersection(point_pos, .{ 1, 0 }, arc.pos_a, arc.pos_b - arc.pos_a) > 0)
                inside = !inside;
            const point_angle = arc.angleOnPoint(point_pos);
            if (std.math.sign(point_angle) == std.math.sign(arc.angle) and @fabs(point_angle) < @fabs(arc.angle))
                inside = !inside;
        }
        return inside;
    }
};

pub const Circle = struct {
    pos: Vec2,
    radius: f32,

    pub fn draw(circle: Circle, color: render.Color, buffer: *render.Buffer) !void {
        try buffer.append(.{
            .positions = &.{ circle.pos + Vec2{ -circle.radius, 0 }, circle.pos + Vec2{ circle.radius, 0 } },
            .angles = &.{ std.math.pi / 2.0, std.math.pi / 2.0 },
        }, color);
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

    fn drawCap(stroke: Stroke, pos: Vec2, dir_a: Vec2, dir_b: Vec2, color: render.Color, buffer: *render.Buffer) !void {
        if (vec2.dot(dir_a, dir_b) == 0)
            return; // directions are opposite, no cap is needed

        const sdir_a = vec2.normalize(-dir_a) * vec2.splat(stroke.width);
        const sdir_b = vec2.normalize(-dir_b) * vec2.splat(stroke.width);
        const sdir = if (vec2.dot(dir_a, dir_b) == 1) sdir_a else vec2.normalize(sdir_a + sdir_b) * vec2.splat(stroke.width);

        const side = vec2.dot(normal(sdir_a), sdir_b) < 0;
        const normal_a = if (side) -normal(sdir_a) else normal(sdir_a);
        const normal_b = if (side) normal(sdir_b) else -normal(sdir_b);

        switch (stroke.cap) {
            .none => {},
            .round => {
                try buffer.append(.{
                    .positions = &.{ pos, pos + normal_a, pos + normal_b },
                    .angles = &.{ 0, Arc.angleOnPoint(.{ .pos_a = normal_a, .pos_b = normal_b }, sdir), 0 },
                }, color);
            },
            .bevel => {
                try buffer.append(.{
                    .positions = &.{ pos, pos + normal_a, pos + normal_b },
                    .angles = &.{ 0, 0, 0 },
                }, color);
            },
            .miter => {
                const tip_dist = linesIntersection(.{ 0, 0 }, sdir, normal_a, dir_a);
                if (tip_dist > 0 and tip_dist < 8) {
                    try buffer.append(.{
                        .positions = &.{ pos, pos + normal_a, pos + sdir * vec2.splat(tip_dist), pos + normal_b },
                        .angles = &.{ 0, 0, 0, 0 },
                    }, color);
                } else {
                    try buffer.append(.{
                        .positions = &.{ pos, pos + normal_a, pos + normal_a + sdir_a, pos + normal_b + sdir_b, pos + normal_b },
                        .angles = &.{ 0, 0, 0, 0, 0 },
                    }, color);
                }
            },
        }
    }

    fn drawSegment(stroke: Stroke, arc: Arc, color: render.Color, buffer: *render.Buffer) !void {
        const normal_a = vec2.normalize(normal(arc.dirA())) * vec2.splat(stroke.width);
        const normal_b = vec2.normalize(normal(arc.dirB())) * vec2.splat(stroke.width);

        try buffer.append(.{
            .positions = &.{ arc.pos_a + normal_a, arc.pos_b - normal_b, arc.pos_b + normal_b, arc.pos_a - normal_a },
            .angles = &.{ arc.angle, 0, -arc.angle, 0 },
        }, color);
    }

    pub const Generator = struct {
        stroke: Stroke,
        color: render.Color,
        buffer: *render.Buffer,
        last_pos: Vec2,
        last_dir: Vec2 = .{ -1, 0 },
        first_pos: Vec2,
        first_dir: Vec2 = .{ 1, 0 },
        is_first: bool = true,

        pub fn add(g: *Generator, angle: f32, pos: Vec2) !void {
            const arc = Arc{ .pos_a = g.last_pos, .pos_b = pos, .angle = angle };
            if (g.is_first) {
                g.first_dir = arc.dirA();
                g.is_first = false;
            } else {
                try g.stroke.drawCap(g.last_pos, g.last_dir, arc.dirA(), g.color, g.buffer);
            }
            try g.stroke.drawSegment(arc, g.color, g.buffer);
            g.last_pos = pos;
            g.last_dir = arc.dirB();
        }
        pub fn finish(g: *Generator) !void {
            try g.stroke.drawCap(g.first_pos, g.first_dir, g.first_dir, g.color, g.buffer);
            try g.stroke.drawCap(g.last_pos, g.last_dir, g.last_dir, g.color, g.buffer);
            g.* = undefined;
        }
        pub fn finishLoop(g: *Generator, angle: f32) !void {
            const arc = Arc{ .pos_a = g.last_pos, .pos_b = g.first_pos, .angle = angle };
            try g.stroke.drawCap(g.last_pos, g.last_dir, arc.dirA(), g.color, g.buffer);
            try g.stroke.drawSegment(arc, g.color, g.buffer);
            try g.stroke.drawCap(g.first_pos, arc.dirB(), g.first_dir, g.color, g.buffer);
            g.* = undefined;
        }
    };
    pub inline fn begin(stroke: Stroke, pos: Vec2, color: render.Color, buffer: *render.Buffer) Generator {
        return .{ .stroke = stroke, .color = color, .buffer = buffer, .first_pos = pos, .last_pos = pos };
    }

    pub fn drawPoint(stroke: Stroke, pos: Vec2, color: render.Color, buffer: *render.Buffer) !void {
        var generator = stroke.begin(pos, color, buffer);
        try generator.finish();
    }

    pub fn drawArc(stroke: Stroke, arc: Arc, color: render.Color, buffer: *render.Buffer) !void {
        var generator = stroke.begin(arc.pos_a, color, buffer);
        try generator.add(arc.angle, arc.pos_b);
        try generator.finish();
    }

    pub fn drawPath(stroke: Stroke, path: Path, color: render.Color, buffer: *render.Buffer) !void {
        var generator = stroke.begin(path.positions[0], color, buffer);
        var i: usize = 0;
        while (i + 1 < path.len()) : (i += 1) {
            try generator.add(path.angles[i], path.positions[i + 1]);
        }
        if (path.isLooped()) {
            try generator.finishLoop(path.angles[i]);
        } else {
            try generator.finish();
        }
    }
};
