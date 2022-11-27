const geometry = @import("geometry.zig");
const render = @import("render.zig");
const vec2 = @import("linalg.zig").vec(2, f32);
const mat3 = @import("linalg.zig").mat(3, f32);

pub const Letter = struct {
    width: f32 = 0,
    paths: []const geometry.Path = &.{},
    strokes: []const geometry.Stroke = &.{},
};

pub const core_font = @import("text/core_font.zig").font;

pub fn drawString(
    string: [:0]const u8,
    font: [128]Letter,
    transform: mat3.Matrix,
    stroke: geometry.Stroke,
    color: render.Color,
    buffer: *render.Buffer,
) !void {
    var offset: f32 = 0;
    for (string) |char| {
        if (char >= 128)
            continue;
        const letter = font[char];
        for (letter.paths) |path| {
            var generator = stroke.begin(applyTransform(path.positions[0], offset, transform), color, buffer);
            var i: usize = 0;
            while (i + 1 < path.len()) : (i += 1) {
                try generator.add(path.angles[i], applyTransform(path.positions[i + 1], offset, transform));
            }
            if (path.isLooped()) {
                try generator.finishLoop(path.angles[i]);
            } else {
                try generator.finish();
            }
        }
        offset += letter.width;
    }
}

fn applyTransform(pos: vec2.Vector, offset: f32, transform: mat3.Matrix) vec2.Vector {
    const transformed = mat3.multVec(transform, .{ pos[0] + offset, pos[1], 1 });
    return vec2.Vector{ transformed[0], transformed[1] } / vec2.splat(transformed[2]);
}
