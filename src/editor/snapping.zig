const std = @import("std");
const geometry = @import("../geometry.zig");
const state = @import("state.zig");
const Drawing = @import("Drawing.zig");

fn distToPoint(pos: geometry.Vec2, point: geometry.Vec2) f32 {
    return geometry.vec2.abs(pos - point);
}
pub fn shouldSnapToPoint(pos: geometry.Vec2, point: geometry.Vec2) bool {
    return distToPoint(pos, point) < state.snapDist();
}

fn distToArc(pos: geometry.Vec2, arc: geometry.Arc) f32 {
    return geometry.vec2.abs(arc.pos_a - arc.pos_b) * @fabs(@tan(arc.angleOnPoint(pos) / 2) - @tan(arc.angle / 2)) / 2;
}
pub fn shouldSnapToArc(pos: geometry.Vec2, arc: geometry.Arc) bool {
    return distToArc(pos, arc) < state.snapDist();
}

const SelectResult = struct {
    index: u32,
    val: union(enum) {
        node: u32,
        segment: u32,
        loop: void,
    },
};
pub fn select(drawing: Drawing, pos: geometry.Vec2) ?SelectResult {
    var result: ?SelectResult = null;
    var best_dist: f32 = state.snapDist();
    var it = drawing.reversePathIterator();
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
pub fn snapToLooseEnd(drawing: Drawing, pos: geometry.Vec2) ?LooseEndResult {
    var result: ?LooseEndResult = null;
    var best_dist: f32 = state.snapDist();
    var it = drawing.pathIterator();
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
