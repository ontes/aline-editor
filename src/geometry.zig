const std = @import("std");
const render = @import("render.zig");

pub const vec2 = @import("linalg.zig").vec(2, f32);
pub const mat2 = @import("linalg.zig").mat(2, f32);
pub const mat3 = @import("linalg.zig").mat(3, f32);
pub const Vec2 = vec2.Vector;
pub const Mat3 = mat3.Matrix;

pub fn normal(vec: Vec2) Vec2 {
    return .{ -vec[1], vec[0] };
}
pub fn rotate(vec: Vec2, angle: f32) Vec2 {
    return mat2.multVec(mat2.rotate(0, 1, angle), vec);
}

pub fn transform(mat: Mat3, vec: Vec2) Vec2 {
    const v = mat3.multVec(mat, .{ vec[0], vec[1], 1 });
    return vec2.Vector{ v[0], v[1] } / vec2.splat(v[2]);
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
        const vec_a = arc.pos_a - point_pos;
        const vec_b = arc.pos_b - point_pos;
        return std.math.atan2(f32, -vec2.dot(vec_a, normal(vec_b)), -vec2.dot(vec_a, vec_b));
    }

    pub fn generate(arc: Arc, gen: anytype) !void {
        var pass = gen.begin();
        try pass.add(arc.pos_a, arc.angle);
        try pass.end(arc.pos_b, null);
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
            const point_angle = arc.angleOnPoint(point_pos);
            if (std.math.sign(point_angle) == std.math.sign(arc.pos_a[0] - point_pos[0]) and
                std.math.sign(point_angle) == std.math.sign(point_pos[0] - arc.pos_b[0]))
                inside = !inside;
            if (std.math.sign(point_angle) == std.math.sign(arc.angle) and @fabs(point_angle) < @fabs(arc.angle))
                inside = !inside;
        }
        return inside;
    }

    pub fn generate(path: Path, gen: anytype) !void {
        var pass = gen.begin();
        var i: usize = 0;
        while (i + 1 < path.len()) : (i += 1)
            try pass.add(path.positions[i], path.angles[i]);
        try pass.end(path.positions[i], if (path.isLooped()) path.angles[i] else null);
    }
};

pub const Circle = struct {
    pos: Vec2,
    radius: f32,

    pub fn generate(circle: Circle, gen: anytype) !void {
        var pass = gen.begin();
        try pass.add(circle.pos + Vec2{ -circle.radius, 0 }, std.math.pi / 2.0);
        try pass.end(circle.pos + Vec2{ circle.radius, 0 }, std.math.pi / 2.0);
    }
};

pub const Rect = struct {
    pos: Vec2,
    radius: Vec2,

    pub fn generate(rect: Rect, gen: anytype) !void {
        var pass = gen.begin();
        try pass.add(rect.pos + Vec2{ rect.radius[0], rect.radius[1] }, 0);
        try pass.add(rect.pos + Vec2{ rect.radius[0], -rect.radius[1] }, 0);
        try pass.add(rect.pos + Vec2{ -rect.radius[0], -rect.radius[1] }, 0);
        try pass.end(rect.pos + Vec2{ -rect.radius[0], rect.radius[1] }, 0);
    }

    pub fn containsPoint(rect: Rect, point: Vec2) bool {
        return @reduce(.And, point >= rect.pos - rect.radius) and
            @reduce(.And, point <= rect.pos + rect.radius);
    }
};

pub const Stadium = struct {
    pos: Vec2,
    radius: Vec2,

    pub fn generate(stadium: Stadium, gen: anytype) !void {
        if (stadium.radius[0] == stadium.radius[1]) {
            try Circle.generate(.{ .pos = stadium.pos, .radius = stadium.radius[0] }, gen);
        } else if (stadium.radius[0] < stadium.radius[1]) {
            const diff = stadium.radius[1] - stadium.radius[0];
            var pass = gen.begin();
            try pass.add(stadium.pos + Vec2{ stadium.radius[0], diff }, 0);
            try pass.add(stadium.pos + Vec2{ stadium.radius[0], -diff }, std.math.pi / 2.0);
            try pass.add(stadium.pos + Vec2{ -stadium.radius[0], -diff }, 0);
            try pass.end(stadium.pos + Vec2{ -stadium.radius[0], diff }, std.math.pi / 2.0);
        } else {
            const diff = stadium.radius[0] - stadium.radius[1];
            var pass = gen.begin();
            try pass.add(stadium.pos + Vec2{ diff, stadium.radius[1] }, std.math.pi / 2.0);
            try pass.add(stadium.pos + Vec2{ diff, -stadium.radius[1] }, 0);
            try pass.add(stadium.pos + Vec2{ -diff, -stadium.radius[1] }, std.math.pi / 2.0);
            try pass.end(stadium.pos + Vec2{ -diff, stadium.radius[1] }, 0);
        }
    }
};

pub const RoundedRect = struct {
    pos: Vec2,
    radius: Vec2,
    corner_radius: f32,

    pub fn generate(rect: RoundedRect, gen: anytype) !void {
        if (rect.corner_radius == 0) {
            try Rect.generate(.{ .pos = rect.pos, .radius = rect.radius }, gen);
        } else if (rect.corner_radius >= @min(rect.radius[0], rect.radius[1])) {
            try Stadium.generate(.{ .pos = rect.pos, .radius = rect.radius }, gen);
        } else {
            var pass = gen.begin();
            try pass.add(rect.pos + Vec2{ rect.radius[0], rect.radius[1] - rect.corner_radius }, 0);
            try pass.add(rect.pos + Vec2{ rect.radius[0], -(rect.radius[1] - rect.corner_radius) }, std.math.pi / 4.0);
            try pass.add(rect.pos + Vec2{ rect.radius[0] - rect.corner_radius, -rect.radius[1] }, 0);
            try pass.add(rect.pos + Vec2{ -(rect.radius[0] - rect.corner_radius), -rect.radius[1] }, std.math.pi / 4.0);
            try pass.add(rect.pos + Vec2{ -rect.radius[0], -(rect.radius[1] - rect.corner_radius) }, 0);
            try pass.add(rect.pos + Vec2{ -rect.radius[0], rect.radius[1] - rect.corner_radius }, std.math.pi / 4.0);
            try pass.add(rect.pos + Vec2{ -(rect.radius[0] - rect.corner_radius), rect.radius[1] }, 0);
            try pass.end(rect.pos + Vec2{ rect.radius[0] - rect.corner_radius, rect.radius[1] }, std.math.pi / 4.0);
        }
    }
};
