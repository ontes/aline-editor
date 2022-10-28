const std = @import("std");
const vec2 = @import("../linalg.zig").vec(f32, 2);
const editor = @import("../editor.zig");
const input = @import("../input.zig");
const render = @import("../render.zig");
const geometry = @import("../geometry.zig");
const platform = @import("../platform.zig");

const selected_stroke = geometry.Stroke{
    .width = 0.01,
    .color = .{ 255, 255, 0, 255 },
    .cap = .rounded,
};

const selected_stroke_cap = geometry.Stroke{
    .width = 0.02,
    .color = .{ 255, 255, 0, 255 },
    .cap = .rounded,
};

pub inline fn canInit() bool {
    return true;
}
pub inline fn init() !void {}
pub inline fn deinit() void {}

pub fn gen(vertices: *geometry.Vertices, indices: *geometry.Indices) !void {
    for (editor.selected_nodes.items) |node| {
        try selected_stroke_cap.genCap(vertices, indices, node.getPos(), null, null);
        if (node.next()) |next_node| if (editor.isSelected(next_node))
            try selected_stroke.genArc(vertices, indices, node.getPos(), next_node.getPos(), node.getAngleFrom());
    }
}

pub fn onEvent(event: platform.Event) !void {
    switch (event) {
        .key_press => |key| switch (key) {
            .mouse_left, .mouse_right => {
                if (!input.isPressed(.left_shift) and !input.isPressed(.right_shift)) {
                    editor.selected_nodes.clearRetainingCapacity();
                }
                if (selectedNode(input.mouse_pos, 0.04)) |node| {
                    if (editor.findSelected(node)) |node_index| {
                        _ = editor.selected_nodes.swapRemove(node_index);
                    } else {
                        try editor.selected_nodes.append(node);
                    }
                } else if (selectedArc(input.mouse_pos, std.math.pi / 10.0)) |node| {
                    const next_node = node.next() orelse unreachable;
                    const node_index = editor.findSelected(node);
                    const next_node_index = editor.findSelected(next_node);
                    if (node_index != null and next_node_index != null) {
                        _ = editor.selected_nodes.swapRemove(node_index.?);
                        _ = editor.selected_nodes.swapRemove(editor.findSelected(next_node).?); // next_node_index can be invalid because we removed node_index
                    } else {
                        if (node_index == null)
                            try editor.selected_nodes.append(node);
                        if (next_node_index == null)
                            try editor.selected_nodes.append(next_node);
                    }
                }
                // TODO search for collisions with solids
            },
            else => {},
        },
        else => {},
    }
}

fn selectedNode(pos: [2]f32, max_distance: f32) ?editor.Node {
    const max_norm = max_distance * max_distance;
    var best_norm = max_norm;
    var best_index: ?editor.Node = null;
    for (editor.paths.items) |path, path_index| {
        for (path.positions.items) |node_pos, index| {
            const norm = vec2.norm(vec2.subtract(pos, node_pos));
            if (norm < max_norm and norm < best_norm) {
                best_norm = norm;
                best_index = .{ .path_index = @intCast(u32, path_index), .index = @intCast(u32, index) };
            }
        }
    }
    return best_index;
}

fn selectedArc(pos: [2]f32, max_angle_diff: f32) ?editor.Node {
    var best_angle_diff = max_angle_diff;
    var best_index: ?editor.Node = null;
    for (editor.paths.items) |dynamic_path, path_index| {
        const path = dynamic_path.toPath();
        var index: u32 = 0;
        while (index < path.len()) : (index += 1) {
            if (path.nextIndex(index)) |next_index| {
                const desired_angle = std.math.pi - 2 * path.getAngleFrom(index);
                const angle_diff = @fabs(angleBetween(pos, path.getPos(index), path.getPos(next_index)) - desired_angle);
                if (angle_diff < max_angle_diff and angle_diff < best_angle_diff) {
                    best_angle_diff = angle_diff;
                    best_index = .{ .path_index = @intCast(u32, path_index), .index = @intCast(u32, index) };
                }
            }
        }
    }
    return best_index;
}

fn angleBetween(center: [2]f32, pos_a: [2]f32, pos_b: [2]f32) f32 {
    const vec_a = vec2.subtract(pos_a, center);
    const vec_b = vec2.subtract(pos_b, center);
    return std.math.acos(vec2.dot(vec_a, vec_b) / vec2.abs(vec_a) / vec2.abs(vec_b));
}
