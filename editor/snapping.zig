const std = @import("std");
const math = @import("math");

const canvas = @import("canvas.zig");
const Image = @import("Image.zig");

fn distToPoint(pos: math.Vec2, point: math.Vec2) f32 {
    return math.vec2.abs(pos - point);
}
pub fn shouldSnapToPoint(pos: math.Vec2, point: math.Vec2) bool {
    return distToPoint(pos, point) < canvas.snapDist();
}

fn distToArc(pos: math.Vec2, arc: math.Arc) f32 {
    return math.vec2.abs(arc.pos_a - arc.pos_b) * @fabs(@tan(arc.angleOnPoint(pos) / 2) - @tan(arc.angle / 2)) / 2;
}
pub fn shouldSnapToArc(pos: math.Vec2, arc: math.Arc) bool {
    return distToArc(pos, arc) < canvas.snapDist();
}

const SelectResult = struct {
    index: u32,
    val: union(enum) {
        node: u32,
        segment: u32,
        loop: void,
    },
};
pub fn select(image: Image, pos: math.Vec2) ?SelectResult {
    var result: ?SelectResult = null;
    var best_dist: f32 = canvas.snapDist();
    var it = image.reversePathIterator();
    while (it.next()) |path| {
        var node: u32 = 0;
        while (node < path.len()) : (node += 1) {
            const dist = distToPoint(pos, path.positions[node]);
            if (dist < best_dist) {
                best_dist = dist;
                result = .{ .index = it.getIndex(), .val = .{ .node = node } };
            }
        }
        var segment: u32 = 0;
        while (segment < path.angles.len) : (segment += 1) {
            const dist = distToArc(pos, path.getArc(segment));
            if (dist < best_dist) {
                best_dist = dist;
                result = .{ .index = it.getIndex(), .val = .{ .segment = segment } };
            }
        }
        if (path.isLooped() and it.getStyle().isFilled() and path.containsPoint(pos)) {
            return result orelse .{ .index = it.getIndex(), .val = .loop };
        }
    }
    return result;
}

const LooseEndResult = struct {
    index: u32,
    node: u32,
};
pub fn snapToLooseEnd(image: Image, pos: math.Vec2) ?LooseEndResult {
    var result: ?LooseEndResult = null;
    var best_dist: f32 = canvas.snapDist();
    var it = image.pathIterator();
    while (it.next()) |path| {
        if (!path.isLooped()) {
            for ([_]u32{ 0, path.len() - 1 }) |node| {
                const dist = distToPoint(pos, path.positions[node]);
                if (dist < best_dist) {
                    best_dist = dist;
                    result = .{ .index = it.getIndex(), .node = node };
                }
            }
        }
    }
    return result;
}
