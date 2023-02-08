const std = @import("std");
const linalg = @import("linalg.zig");
const geometry = @import("geometry.zig");

pub const Stroke = struct {
    width: f32,
    cap: CapStyle = .none,

    pub const CapStyle = enum {
        none,
        round,
        bevel,
        miter,
    };

    pub fn generator(stroke: Stroke, child: anytype) StrokeGenerator(@TypeOf(child)) {
        return .{ .stroke = stroke, .child = child };
    }
};

pub fn StrokeGenerator(comptime Child: type) type {
    return struct {
        stroke: Stroke,
        child: Child,

        const Generator = @This();

        pub fn begin(g: Generator) Pass {
            return .{ .g = g };
        }

        pub const Pass = struct {
            g: Generator,

            is_first: bool = true,
            first_pos: linalg.Vec2 = undefined,
            last_pos: linalg.Vec2 = undefined,
            last_angle: f32 = undefined,

            is_second: bool = true,
            first_dir: linalg.Vec2 = undefined,
            last_dir: linalg.Vec2 = undefined,

            pub fn add(p: *Pass, pos: linalg.Vec2, angle: f32) !void {
                if (p.is_first) {
                    p.first_pos = pos;
                    p.is_first = false;
                } else {
                    const arc = geometry.Arc{ .pos_a = p.last_pos, .angle = p.last_angle, .pos_b = pos };
                    if (p.is_second) {
                        p.first_dir = arc.dirA();
                        p.is_second = false;
                    } else {
                        try p.g.generateCap(p.last_pos, p.last_dir, arc.dirA());
                    }
                    try p.g.generateSegment(arc);
                    p.last_dir = arc.dirB();
                }
                p.last_pos = pos;
                p.last_angle = angle;
            }

            pub fn end(p: Pass) !void {
                if (p.is_second) { // single node
                    std.debug.assert(std.math.isNan(p.last_angle)); // single point can't be looped
                    try p.g.generateCap(p.first_pos, .{ 1, 0 }, .{ 1, 0 });
                    try p.g.generateCap(p.last_pos, .{ -1, 0 }, .{ -1, 0 });
                } else if (!std.math.isNan(p.last_angle)) { // looped path
                    const arc = geometry.Arc{ .pos_a = p.last_pos, .pos_b = p.first_pos, .angle = p.last_angle };
                    try p.g.generateCap(p.last_pos, p.last_dir, arc.dirA());
                    try p.g.generateSegment(arc);
                    try p.g.generateCap(p.first_pos, arc.dirB(), p.first_dir);
                } else {
                    try p.g.generateCap(p.first_pos, p.first_dir, p.first_dir);
                    try p.g.generateCap(p.last_pos, p.last_dir, p.last_dir);
                }
            }
        };

        fn generateCap(g: Generator, pos: linalg.Vec2, dir_a: linalg.Vec2, dir_b: linalg.Vec2) !void {
            const ndir_a = -linalg.vec2.normalize(dir_a);
            const ndir_b = -linalg.vec2.normalize(dir_b);

            const dot = linalg.vec2.dot(ndir_a, ndir_b);
            if (dot == -1) return; // directions are opposite, no cap is needed

            const sdir = (if (dot == 1) ndir_a else linalg.vec2.normalize(ndir_a + ndir_b)) * linalg.vec2.splat(g.stroke.width);
            const sdir_a = ndir_a * linalg.vec2.splat(g.stroke.width);
            const sdir_b = ndir_b * linalg.vec2.splat(g.stroke.width);

            const side = linalg.vec2.dot(geometry.normal(ndir_a), ndir_b) < 0;
            const normal_a = if (side) -geometry.normal(sdir_a) else geometry.normal(sdir_a);
            const normal_b = if (side) geometry.normal(sdir_b) else -geometry.normal(sdir_b);

            switch (g.stroke.cap) {
                .none => {},
                .round => {
                    var pass = g.child.begin();
                    try pass.add(pos + normal_a, geometry.Arc.angleOnPoint(.{ .pos_a = normal_a, .pos_b = normal_b }, sdir));
                    try pass.add(pos + normal_b, 0);
                    try pass.add(pos, 0);
                    try pass.end();
                },
                .bevel => {
                    var pass = g.child.begin();
                    try pass.add(pos + normal_a, 0);
                    try pass.add(pos + normal_b, 0);
                    try pass.add(pos, 0);
                    try pass.end();
                },
                .miter => {
                    var pass = g.child.begin();
                    try pass.add(pos + normal_a, 0);
                    const tip_dist = (normal_a[0] * dir_a[1] - normal_a[1] * dir_a[0]) / (sdir[0] * dir_a[1] - sdir[1] * dir_a[0]);
                    if (tip_dist > 0 and tip_dist < 4) {
                        try pass.add(pos + sdir * linalg.vec2.splat(tip_dist), 0);
                    } else {
                        try pass.add(pos + normal_a + sdir_a, 0);
                        try pass.add(pos + normal_b + sdir_b, 0);
                    }
                    try pass.add(pos + normal_b, 0);
                    try pass.add(pos, 0);
                    try pass.end();
                },
            }
        }

        fn generateSegment(g: Generator, arc: geometry.Arc) !void {
            const normal_a = linalg.vec2.normalize(geometry.normal(arc.dirA())) * linalg.vec2.splat(g.stroke.width);
            const normal_b = linalg.vec2.normalize(geometry.normal(arc.dirB())) * linalg.vec2.splat(g.stroke.width);

            var pass = g.child.begin();
            try pass.add(arc.pos_a - normal_a, 0);
            try pass.add(arc.pos_a + normal_a, arc.angle);
            try pass.add(arc.pos_b - normal_b, 0);
            try pass.add(arc.pos_b + normal_b, -arc.angle);
            try pass.end();
        }
    };
}

pub fn transformGenerator(mat: linalg.Mat3, child: anytype) TransformGenerator(@TypeOf(child)) {
    return .{ .mat = mat, .child = child };
}

pub fn TransformGenerator(comptime Child: type) type {
    return struct {
        mat: linalg.Mat3,
        child: Child,

        const Generator = @This();

        pub fn begin(g: Generator) Pass {
            return .{ .g = g, .child_pass = g.child.begin() };
        }

        pub const Pass = struct {
            g: Generator,
            child_pass: Child.Pass,

            pub fn add(p: *Pass, pos: linalg.Vec2, angle: f32) !void {
                return p.child_pass.add(geometry.transform(p.g.mat, pos), angle); // TODO multiply angle by sign of determinant
            }

            pub fn end(p: Pass) !void {
                return p.child_pass.end();
            }
        };
    };
}
