const std = @import("std");
const math = @import("math");

const Image = @import("Image.zig");

fn distToPoint(pos: math.Vec2, point: math.Vec2) f32 {
    return math.vec2.abs(pos - point);
}
pub fn shouldSnapToPoint(pos: math.Vec2, point: math.Vec2, snap_dist: f32) bool {
    return distToPoint(pos, point) < snap_dist;
}

fn distToArc(pos: math.Vec2, arc: math.Arc) f32 {
    return math.vec2.abs(arc.pos_a - arc.pos_b) * @fabs(@tan(arc.angleOnPoint(pos) / 2) - @tan(arc.angle / 2)) / 2;
}
pub fn shouldSnapToArc(pos: math.Vec2, arc: math.Arc, snap_dist: f32) bool {
    return distToArc(pos, arc) < snap_dist;
}

const SelectResult = struct {
    index: usize,
    val: union(enum) {
        node: usize,
        segment: usize,
        loop: void,
    },
};
pub fn select(image: Image, pos: math.Vec2, snap_dist: f32) ?SelectResult {
    var result: ?SelectResult = null;
    var best_dist: f32 = snap_dist;
    var it = image.reversedIterator();
    while (it.next()) |path| {
        var node: usize = 0;
        while (node < path.getNodeCount()) : (node += 1) {
            const dist = distToPoint(pos, path.getPos(node));
            if (dist < best_dist) {
                best_dist = dist;
                result = .{ .index = path.index, .val = .{ .node = node } };
            }
        }
        var segment: usize = 0;
        while (segment < path.getSegmentCount()) : (segment += 1) {
            const dist = distToArc(pos, path.getArc(segment));
            if (dist < best_dist) {
                best_dist = dist;
                result = .{ .index = path.index, .val = .{ .segment = segment } };
            }
        }
        if (path.isLooped() and path.getStyle().isFilled() and path.containsPoint(pos)) {
            return result orelse .{ .index = path.index, .val = .loop };
        }
    }
    return result;
}

const LooseEndResult = struct {
    index: usize,
    node: usize,
};
pub fn snapToLooseEnd(image: Image, pos: math.Vec2, snap_dist: f32) ?LooseEndResult {
    var result: ?LooseEndResult = null;
    var best_dist: f32 = snap_dist;
    var it = image.iterator();
    while (it.next()) |path| {
        if (!path.isLooped()) {
            for ([_]usize{ 0, path.getNodeCount() - 1 }) |node| {
                const dist = distToPoint(pos, path.getPos(node));
                if (dist < best_dist) {
                    best_dist = dist;
                    result = .{ .index = path.index, .node = node };
                }
            }
        }
    }
    return result;
}
