const geometry = @import("geometry.zig");
const render = @import("render.zig");
const generators = @import("generators.zig");
const mat3 = @import("linalg.zig").mat(3, f32);

pub const Letter = struct {
    width: f32 = 0,
    paths: []const geometry.Path = &.{},
    strokes: []const generators.Stroke = &.{},
};

pub const core_font = @import("text/core_font.zig").font;

pub fn generateString(
    string: [:0]const u8,
    font: [128]Letter,
    gen: anytype,
) !void {
    var offset: f32 = 0;
    for (string) |char| {
        if (char >= 128)
            continue;
        const letter = font[char];
        var t_gen = generators.transformGenerator(mat3.translate(.{ offset, 0 }), gen);
        for (letter.paths) |path|
            try path.generate(&t_gen);
        offset += letter.width;
    }
}
