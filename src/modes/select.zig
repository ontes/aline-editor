const std = @import("std");
const vec2 = @import("../linalg.zig").vec(f32, 2);
const editor = @import("../editor.zig");
const input = @import("../input.zig");
const render = @import("../render.zig");
const geometry = @import("../geometry.zig");
const platform = @import("../platform.zig");

const color = [4]u8{ 255, 255, 0, 255 };
const stroke = geometry.Stroke{ .width = 0.005, .cap = .none };

pub inline fn canInit() bool {
    return true;
}
pub inline fn init() !void {}
pub inline fn deinit() void {}

pub fn gen(buffer: *render.Buffer) !void {
    for (editor.selected_nodes.items) |node| {
        try geometry.Circle.gen(.{ .pos = node.getPos(), .radius = 0.01 }, color, buffer);
        if (node.next()) |next_node| if (editor.isSelected(next_node))
            try stroke.genArc(node.getArcFrom().?, color, buffer);
    }
}

pub fn onEvent(event: platform.Event) !void {
    switch (event) {
        .key_press => |key| switch (key) {
            .mouse_left, .mouse_right => {
                if (!input.isPressed(.left_shift) and !input.isPressed(.right_shift))
                    editor.selected_nodes.clearRetainingCapacity();
                try select(input.mouse_pos);
            },
            else => {},
        },
        else => {},
    }
}

fn select(pos: [2]f32) !void {
    var i: u32 = 0;
    while (i < editor.objects.items.len) : (i += 1) {
        const object_index = @intCast(u32, editor.objects.items.len - i - 1);
        const path = editor.objects.items[object_index].toPath();
        if (selectedNode(path, pos, 0.04 * 0.04)) |index| {
            const node = editor.Node{ .object_index = object_index, .index = index };
            if (editor.findSelected(node)) |node_index| {
                _ = editor.selected_nodes.swapRemove(node_index);
            } else {
                try editor.selected_nodes.append(node);
            }
            return;
        }
        if (selectedArc(path, pos, std.math.pi / 10.0)) |index| {
            const node = editor.Node{ .object_index = object_index, .index = index };
            const next_node = node.next().?;
            var allready_selected = true;
            if (!editor.isSelected(node)) {
                allready_selected = false;
                try editor.selected_nodes.append(node);
            }
            if (!editor.isSelected(next_node)) {
                allready_selected = false;
                try editor.selected_nodes.append(next_node);
            }
            if (allready_selected) {
                _ = editor.selected_nodes.swapRemove(editor.findSelected(node).?);
                _ = editor.selected_nodes.swapRemove(editor.findSelected(next_node).?);
            }
            return;
        }
        if (path.isLooped() and path.isInside(pos)) {
            var allready_selected = true;
            var index: u32 = 0;
            while (index < path.len()) : (index += 1) {
                const node = editor.Node{ .object_index = object_index, .index = index };
                if (!editor.isSelected(node)) {
                    allready_selected = false;
                    try editor.selected_nodes.append(node);
                }
            }
            if (allready_selected) {
                index = 0;
                while (index < path.len()) : (index += 1) {
                    const node = editor.Node{ .object_index = object_index, .index = index };
                    _ = editor.selected_nodes.swapRemove(editor.findSelected(node).?);
                }
            }
            return;
        }
    }
}

fn selectedNode(path: geometry.Path, pos: [2]f32, max_norm: f32) ?u32 {
    var index: u32 = 0;
    while (index < path.len()) : (index += 1) {
        const norm = vec2.norm(vec2.subtract(pos, path.getPos(index)));
        if (norm < max_norm)
            return index;
    }
    return null;
}

fn selectedArc(path: geometry.Path, pos: [2]f32, max_angle_diff: f32) ?u32 {
    var index: u32 = 0;
    while (index < path.len()) : (index += 1) {
        if (path.nextIndex(index)) |next_index| {
            const angle = geometry.arcAngleFromPoint(path.getPos(index), path.getPos(next_index), pos);
            const angle_diff = @fabs(angle - path.getAngleFrom(index).?);
            if (angle_diff < max_angle_diff)
                return index;
        }
    }
    return null;
}
