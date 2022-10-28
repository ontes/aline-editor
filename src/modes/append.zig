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

const new_path_stroke = geometry.Stroke{
    .width = 0.01,
    .color = .{ 255, 255, 255, 255 },
    .cap = .rounded,
};

pub fn getNode() *editor.Node {
    return &editor.selected_nodes.items[0];
}

pub fn canInit() bool {
    return editor.selected_nodes.items.len == 0 or
        (editor.selected_nodes.items.len == 1 and (getNode().prev() == null or getNode().next() == null));
}

pub fn init() !void {
    if (editor.selected_nodes.items.len == 0) { // creating a new path
        try editor.paths.append(try editor.DynamicPath.init(editor.paths.allocator, input.mouse_pos, new_path_stroke));
        try editor.selected_nodes.append(.{ .path_index = @intCast(u32, editor.paths.items.len - 1), .index = 0 });
        try editor.step();
    } else if (getNode().prev() == null) { // appending to beggining
        getNode().getDynamicPath().reverse();
        getNode().index = getNode().getPath().len() - 1;
    }
}

pub fn deinit() void {}

pub fn gen(out_vertices: *geometry.Vertices, out_indices: *geometry.Indices) !void {
    try geometry.Path.gen(.{
        .positions = &.{ getNode().getPos(), input.mouse_pos },
        .angles = &.{0.0},
        .stroke = preview_stroke,
    }, out_vertices, out_indices);
}

pub fn onEvent(event: platform.Event) !void {
    switch (event) {
        .key_release => |key| switch (key) {
            .mouse_left => {
                if (vec2.norm(vec2.subtract(input.mouse_pos, getNode().getPath().getPos(0))) < 0.05 * 0.05) { // ending by creating a loop
                    try getNode().getDynamicPath().loop(0);
                    getNode().index = 0;
                    _ = try editor.setMode(.select);
                } else { // adding a new segment
                    try getNode().getDynamicPath().append(input.mouse_pos, 0);
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

// pub fn onMouseMove(mode: *Mode) !void {
//     if (mode.data) |*data| {
//         if (!input.isPressed(.mouse_left)) {
//             data.to_pos = input.mouse_pos;
//         } else {
//             data.angle = computeAngle(data.path().lastPos(), data.to_pos, input.mouse_pos);
//         }
//     }
// }

// fn computeAngle(from: [2]f32, to: [2]f32, mouse: [2]f32) f32 {
//     const a = vec2.subtract(from, to);
//     const b = vec2.subtract(to, mouse);
//     var angle = std.math.atan2(f32, b[1], b[0]) - std.math.atan2(f32, a[1], a[0]);
//     if (angle < -std.math.pi) angle += 2 * std.math.pi;
//     if (angle > std.math.pi) angle -= 2 * std.math.pi;
//     return angle * 2;
// }
