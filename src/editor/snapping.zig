const std = @import("std");
const geometry = @import("../geometry.zig");
const vec2 = @import("../linalg.zig").vec(2, f32);
const input = @import("input.zig");
const Drawing = @import("Drawing.zig");

pub fn distToPoint(pos_a: geometry.Vec2, pos_b: geometry.Vec2) f32 {
    return vec2.abs(pos_a - pos_b);
}
pub fn distToArc(arc: geometry.Arc, pos: geometry.Vec2) f32 {
    return vec2.abs(arc.pos_a - arc.pos_b) * @fabs(@tan(arc.angleOnPoint(pos) / 2) - @tan(arc.angle / 2)) / 2;
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
    var best_dist: f32 = input.snapDist();
    var it = drawing.reversePathIterator();
    while (it.next()) |path| {
        var node: u32 = 0;
        while (node < path.len()) : (node += 1) {
            const dist = distToPoint(path.positions[node], pos);
            if (dist < best_dist) {
                best_dist = dist;
                result = .{ .index = it.getIndex(), .val = .{ .node = node } };
            }
        }
        var segment: u32 = 0;
        while (segment < path.angles.len) : (segment += 1) {
            const dist = distToArc(path.getArc(segment), pos);
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

pub fn closestLooseEnd(path: geometry.Path, pos: geometry.Vec2) u32 {
    return if (distToPoint(path.positions[0], pos) <= distToPoint(path.positions[path.len() - 1], pos)) 0 else path.len() - 1;
}
