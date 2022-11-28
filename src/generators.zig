const std = @import("std");
const geometry = @import("geometry.zig");
const vec2 = @import("linalg.zig").vec(2, f32);

pub const Stroke = struct {
    width: f32,
    cap: CapStyle,

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
            first_pos: geometry.Vec2 = undefined,
            last_pos: geometry.Vec2 = undefined,
            last_angle: f32 = undefined,

            is_second: bool = true,
            first_dir: geometry.Vec2 = undefined,
            last_dir: geometry.Vec2 = undefined,

            pub fn add(p: *Pass, pos: geometry.Vec2, angle: f32) !void {
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

            pub fn end(p: *Pass, pos: geometry.Vec2, angle: ?f32) !void {
                try p.add(pos, angle orelse 0);
                if (p.is_second) {
                    std.debug.assert(angle == null); // single point can't be looped
                    try p.g.generateCap(p.first_pos, .{ 1, 0 }, .{ 1, 0 });
                    try p.g.generateCap(p.last_pos, .{ -1, 0 }, .{ -1, 0 });
                } else if (angle == null) {
                    try p.g.generateCap(p.first_pos, p.first_dir, p.first_dir);
                    try p.g.generateCap(p.last_pos, p.last_dir, p.last_dir);
                } else {
                    const arc = geometry.Arc{ .pos_a = p.last_pos, .pos_b = p.first_pos, .angle = angle.? };
                    try p.g.generateCap(p.last_pos, p.last_dir, arc.dirA());
                    try p.g.generateSegment(arc);
                    try p.g.generateCap(p.first_pos, arc.dirB(), p.first_dir);
                }
                p.* = undefined;
            }
        };

        fn generateCap(g: Generator, pos: geometry.Vec2, dir_a: geometry.Vec2, dir_b: geometry.Vec2) !void {
            const ndir_a = -vec2.normalize(dir_a);
            const ndir_b = -vec2.normalize(dir_b);

            const dot = vec2.dot(ndir_a, ndir_b);
            if (dot == -1) return; // directions are opposite, no cap is needed

            const sdir = (if (dot == 1) ndir_a else vec2.normalize(ndir_a + ndir_b)) * vec2.splat(g.stroke.width);
            const sdir_a = ndir_a * vec2.splat(g.stroke.width);
            const sdir_b = ndir_b * vec2.splat(g.stroke.width);

            const side = vec2.dot(geometry.normal(ndir_a), ndir_b) < 0;
            const normal_a = if (side) -geometry.normal(sdir_a) else geometry.normal(sdir_a);
            const normal_b = if (side) geometry.normal(sdir_b) else -geometry.normal(sdir_b);

            var pass = g.child.begin();
            switch (g.stroke.cap) {
                .none => {},
                .round => {
                    try pass.add(pos + normal_a, geometry.Arc.angleOnPoint(.{ .pos_a = normal_a, .pos_b = normal_b }, sdir));
                    try pass.add(pos + normal_b, 0);
                },
                .bevel => {
                    try pass.add(pos + normal_a, 0);
                    try pass.add(pos + normal_b, 0);
                },
                .miter => {
                    try pass.add(pos + normal_a, 0);
                    const tip_dist = (normal_a[0] * dir_a[1] - normal_a[1] * dir_a[0]) / (sdir[0] * dir_a[1] - sdir[1] * dir_a[0]);
                    if (tip_dist > 0 and tip_dist < 8) {
                        try pass.add(pos + sdir * vec2.splat(tip_dist), 0);
                    } else {
                        try pass.add(pos + normal_a + sdir_a, 0);
                        try pass.add(pos + normal_b + sdir_b, 0);
                    }
                    try pass.add(pos + normal_b, 0);
                },
            }
            try pass.end(pos, 0);
        }

        fn generateSegment(g: Generator, arc: geometry.Arc) !void {
            const normal_a = vec2.normalize(geometry.normal(arc.dirA())) * vec2.splat(g.stroke.width);
            const normal_b = vec2.normalize(geometry.normal(arc.dirB())) * vec2.splat(g.stroke.width);

            var pass = g.child.begin();
            try pass.add(arc.pos_a - normal_a, 0);
            try pass.add(arc.pos_a + normal_a, arc.angle);
            try pass.add(arc.pos_b - normal_b, 0);
            try pass.end(arc.pos_b + normal_b, -arc.angle);
        }
    };
}

pub fn transformGenerator(mat: geometry.Mat3, child: anytype) TransformGenerator(@TypeOf(child)) {
    return .{ .mat = mat, .child = child };
}

pub fn TransformGenerator(comptime Child: type) type {
    return struct {
        mat: geometry.Mat3,
        child: Child,

        const Generator = @This();

        pub fn begin(g: Generator) Pass {
            return .{ .g = g, .child_pass = g.child.begin() };
        }

        pub const Pass = struct {
            g: Generator,
            child_pass: Child.Pass,

            pub fn add(p: *Pass, pos: geometry.Vec2, angle: f32) !void {
                try p.child_pass.add(geometry.transform(p.g.mat, pos), angle); // TODO multiply angle by sign of determinant
            }

            pub fn end(p: *Pass, pos: geometry.Vec2, angle: ?f32) !void {
                try p.child_pass.end(geometry.transform(p.g.mat, pos), angle);
            }
        };
    };
}
