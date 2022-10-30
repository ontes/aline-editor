const std = @import("std");
const vec2 = @import("../linalg.zig").vec(2, f32);
const editor = @import("../editor.zig");
const input = @import("../input.zig");
const geometry = @import("../geometry.zig");
const platform = @import("../platform.zig");
const render = @import("../render.zig");

const color = [4]u8{ 255, 32, 32, 255 };
const stroke = geometry.Stroke{ .width = 0.005, .cap = .none };

pub fn canInit() bool {
    return editor.selected_nodes.items.len == 2 and getNode(0).object_index == getNode(1).object_index and
        ((if (getNode(0).next()) |next_node| next_node.index == getNode(1).index else false) or
        (if (getNode(0).prev()) |prev_node| prev_node.index == getNode(1).index else false));
}

pub fn init() !void {
    if (getNode(0).prev()) |prev_node| if (prev_node.index == getNode(1).index)
        std.mem.swap(editor.Node, getNode(0), getNode(1));
}

pub fn deinit() void {}

pub fn gen(buffer: *render.Buffer) !void {
    var arc = getNode(0).arcFrom().?;
    arc.angle = getAngle();
    try stroke.genArc(arc, color, buffer);
}

pub fn onEvent(event: platform.Event) !void {
    switch (event) {
        .key_release => |key| switch (key) {
            .mouse_left => {
                getNode(0).getObject().angles.items[getNode(0).index] = getAngle();
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

inline fn getNode(index: usize) *editor.Node {
    return &editor.selected_nodes.items[index];
}

fn getAngle() f32 {
    return getNode(0).arcFrom().?.angleOnPoint(input.mouse_pos);
}
