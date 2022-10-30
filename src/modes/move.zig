const std = @import("std");
const vec2 = @import("../linalg.zig").vec(2, f32);
const editor = @import("../editor.zig");
const input = @import("../input.zig");
const geometry = @import("../geometry.zig");
const platform = @import("../platform.zig");
const render = @import("../render.zig");

const color = [4]u8{ 255, 32, 32, 255 };
const stroke = geometry.Stroke{ .width = 0.005, .cap = .none };

var start_pos: geometry.Vec2 = undefined;

inline fn getOffset() geometry.Vec2 {
    return input.mouse_pos - start_pos;
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

pub fn gen(buffer: *render.Buffer) !void {
    for (editor.selected_nodes.items) |node| {
        if (node.prev()) |prev_node| {
            if (!editor.isSelected(prev_node)) {
                var arc = node.arcTo().?;
                arc.pos_b = arc.pos_b + getOffset();
                try stroke.genArc(arc, color, buffer);
            }
        }
        if (node.next()) |next_node| {
            var arc = node.arcFrom().?;
            arc.pos_a = arc.pos_a + getOffset();
            if (editor.isSelected(next_node))
                arc.pos_b = arc.pos_b + getOffset();
            try stroke.genArc(arc, color, buffer);
        }
    }
}

pub fn onEvent(event: platform.Event) !void {
    switch (event) {
        .key_press => |key| switch (key) {
            .mouse_left => {
                for (editor.selected_nodes.items) |node|
                    node.getObject().positions.items[node.index] = node.pos() + getOffset();
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
