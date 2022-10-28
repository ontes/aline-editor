const std = @import("std");

pub usingnamespace @import("render/webgpu.zig");

pub const Vertex = struct {
    pos: [2]f32,
    color: [4]u8,
};
