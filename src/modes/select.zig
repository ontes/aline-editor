const std = @import("std");
const vec2 = @import("../linalg.zig").vec(2, f32);
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
        try geometry.Circle.gen(.{ .pos = node.pos(), .radius = 0.01 }, color, buffer);
        if (node.next()) |next_node| if (editor.isSelected(next_node))
            try stroke.genArc(node.arcFrom().?, color, buffer);
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

fn select(pos: geometry.Vec2) !void {
    var i: u32 = 0;
    while (i < editor.objects.items.len) : (i += 1) {
        const object_index = @intCast(u32, editor.objects.items.len - i - 1);
        const path = editor.objects.items[object_index].toPath();
        if (selectedNode(path, pos, 0.05)) |index| {
            const node = editor.Node{ .object_index = object_index, .index = index };
            if (editor.findSelected(node)) |node_index| {
                _ = editor.selected_nodes.swapRemove(node_index);
            } else {
                try editor.selected_nodes.append(node);
            }
            return;
        }
        if (selectedArc(path, pos, 0.1)) |index| {
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
        if (path.isLooped() and path.containsPoint(pos)) {
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

fn selectedNode(path: geometry.Path, pos: geometry.Vec2, max_diff: f32) ?u32 {
    var index: u32 = 0;
    while (index < path.len()) : (index += 1) {
        if (vec2.norm(pos - path.pos(index)) < max_diff * max_diff)
            return index;
    }
    return null;
}

fn selectedArc(path: geometry.Path, pos: geometry.Vec2, max_diff: f32) ?u32 {
    var index: u32 = 0;
    while (index < path.len()) : (index += 1) {
        if (path.arcFrom(index)) |arc| {
            if (@fabs(@tan(arc.angleOnPoint(pos) / 2) - @tan(arc.angle / 2)) < max_diff)
                return index;
        }
    }
    return null;
}
