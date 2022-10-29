const std = @import("std");
const vec2 = @import("../linalg.zig").vec(f32, 2);
const editor = @import("../editor.zig");
const input = @import("../input.zig");
const geometry = @import("../geometry.zig");
const platform = @import("../platform.zig");
const render = @import("../render.zig");

const color = [4]u8{ 255, 32, 32, 255 };
const preview_stroke = geometry.Stroke{ .width = 0.005, .cap = .none };

inline fn getNode() *editor.Node {
    return &editor.selected_nodes.items[0];
}

pub fn canInit() bool {
    return editor.selected_nodes.items.len == 0 or
        (editor.selected_nodes.items.len == 1 and (getNode().prev() == null or getNode().next() == null));
}

pub fn init() !void {
    if (editor.selected_nodes.items.len == 0) { // creating a new path
        try editor.objects.append(try editor.Object.init(editor.objects.allocator, input.mouse_pos));
        try editor.selected_nodes.append(.{ .object_index = @intCast(u32, editor.objects.items.len - 1), .index = 0 });
        try editor.step();
    } else if (getNode().prev() == null) { // appending to beggining
        getNode().getObject().reverse();
        getNode().index = getNode().getPath().len() - 1;
    }
}

pub fn deinit() void {}

pub fn gen(buffer: *render.Buffer) !void {
    try preview_stroke.genArc(.{ .pos_a = getNode().getPos(), .pos_b = input.mouse_pos, .angle = 0 }, color, buffer);
}

pub fn onEvent(event: platform.Event) !void {
    switch (event) {
        .key_release => |key| switch (key) {
            .mouse_left => {
                if (vec2.norm(vec2.subtract(input.mouse_pos, getNode().getPath().getPos(0))) < 0.05 * 0.05) { // ending by creating a loop
                    try getNode().getObject().loop(0);
                    getNode().index = 0;
                    _ = try editor.setMode(.select);
                } else { // adding a new segment
                    try getNode().getObject().append(input.mouse_pos, 0);
                    getNode().index += 1;
                }
                try editor.step();
            },
            .mouse_right => {
                _ = try editor.setMode(.select);
            },
            else => {},
        },
        else => {},
    }
}
