const std = @import("std");
const vec2 = @import("../linalg.zig").vec(f32, 2);
const editor = @import("../editor.zig");
const input = @import("../input.zig");
const geometry = @import("../geometry.zig");
const platform = @import("../platform.zig");

const preview_stroke = geometry.Stroke{
    .width = 0.01,
    .color = .{ 255, 32, 32, 255 },
    .cap = .rounded,
};

var start_pos: [2]f32 = undefined;

inline fn getOffset() [2]f32 {
    return vec2.subtract(input.mouse_pos, start_pos);
}

pub fn canInit() bool {
    return editor.selected_nodes.items.len > 0;
}

pub fn init() !void {
    start_pos = input.mouse_pos;
}

pub fn deinit() void {
    start_pos = undefined;
}

pub fn gen(out_vertices: *geometry.Vertices, out_indices: *geometry.Indices) !void {
    for (editor.selected_nodes.items) |node| {
        if (node.getPath().prevIndex(node.index)) |prev_index| {
            if (!editor.isSelected(.{ .path_index = node.path_index, .index = prev_index })) {
                try preview_stroke.genArc(
                    out_vertices,
                    out_indices,
                    node.getPath().getPos(prev_index),
                    vec2.add(node.getPos(), getOffset()),
                    node.getPath().getAngleTo(node.index),
                );
            }
        }
        try preview_stroke.genCap(
            out_vertices,
            out_indices,
            vec2.add(node.getPos(), getOffset()),
            null,
            null,
        );
        if (node.getPath().nextIndex(node.index)) |next_index| {
            if (!editor.isSelected(.{ .path_index = node.path_index, .index = next_index })) {
                try preview_stroke.genArc(
                    out_vertices,
                    out_indices,
                    vec2.add(node.getPos(), getOffset()),
                    node.getPath().getPos(next_index),
                    node.getPath().getAngleFrom(node.index),
                );
            } else {
                try preview_stroke.genArc(
                    out_vertices,
                    out_indices,
                    vec2.add(node.getPos(), getOffset()),
                    vec2.add(node.getPath().getPos(next_index), getOffset()),
                    node.getPath().getAngleFrom(node.index),
                );
            }
        }
    }
}

pub fn onEvent(event: platform.Event) !void {
    switch (event) {
        .key_press => |key| switch (key) {
            .mouse_left => {
                for (editor.selected_nodes.items) |node|
                    node.getDynamicPath().positions.items[node.index] = vec2.add(node.getPos(), getOffset());
                try editor.step();
                _ = try editor.setMode(.select);
            },
            .mouse_right => {
                _ = try editor.setMode(.select);
            },
            else => {},
        },
        else => {},
    }
}
