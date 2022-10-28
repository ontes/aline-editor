const std = @import("std");
const geometry = @import("../geometry.zig");

const grid_size = 10;

const selected_stroke = geometry.Stroke{
    .width = 0.001,
    .color = .{ 255, 255, 0, 255 },
    .cap = .rounded,
};

pub fn gen(out_vertices: *geometry.Vertices, out_indices: *geometry.Indices) !void {
    var i: u32 = 0;
    while (i <= 1000) : (i += step) {}
}
