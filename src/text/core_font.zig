const std = @import("std");
const text = @import("../text.zig");
const geometry = @import("../geometry.zig");

pub const font: [128]text.Letter = font: {
    var f = [_]text.Letter{.{}} ** 128;

    f['A'] = .{ .width = 9, .paths = &.{
        .{ .positions = &.{ .{ 0, 0 }, .{ 3, 8 }, .{ 6, 0 } }, .angles = &.{ 0, 0 } },
        .{ .positions = &.{ .{ 1, 2 }, .{ 5, 2 } }, .angles = &.{0} },
    } };

    f['B'] = .{ .width = 8, .paths = &.{
        .{ .positions = &.{ .{ 0, 0 }, .{ 0, 8 }, .{ 3, 8 }, .{ 3, 4 }, .{ 3, 0 } }, .angles = &.{ 0, 0, std.math.pi * 0.5, std.math.pi * 0.5, 0 } },
        .{ .positions = &.{ .{ 0, 4 }, .{ 3, 4 } }, .angles = &.{0} },
    } };

    f['C'] = .{ .width = 10, .paths = &.{
        .{ .positions = &.{ .{ 4 + 4 * std.math.sqrt1_2, 4 - 4 * std.math.sqrt1_2 }, .{ 4 + 4 * std.math.sqrt1_2, 4 + 4 * std.math.sqrt1_2 } }, .angles = &.{std.math.pi * 0.75} },
    } };

    f['D'] = .{ .width = 10, .paths = &.{
        .{ .positions = &.{ .{ 0, 0 }, .{ 0, 8 }, .{ 3, 8 }, .{ 3, 0 } }, .angles = &.{ 0, 0, std.math.pi * 0.5, 0 } },
    } };

    f['E'] = .{ .width = 7, .paths = &.{
        .{ .positions = &.{ .{ 4, 0 }, .{ 0, 0 }, .{ 0, 8 }, .{ 4, 8 } }, .angles = &.{ 0, 0, 0 } },
        .{ .positions = &.{ .{ 0, 4 }, .{ 3, 4 } }, .angles = &.{0} },
    } };

    f['F'] = .{ .width = 7, .paths = &.{
        .{ .positions = &.{ .{ 0, 0 }, .{ 0, 8 }, .{ 4, 8 } }, .angles = &.{ 0, 0 } },
        .{ .positions = &.{ .{ 0, 4 }, .{ 3, 4 } }, .angles = &.{0} },
    } };

    f['G'] = .{ .width = 11, .paths = &.{
        .{ .positions = &.{ .{ 6, 4 }, .{ 8, 4 }, .{ 4 + 4 * std.math.sqrt1_2, 4 + 4 * std.math.sqrt1_2 } }, .angles = &.{ 0, std.math.pi * 0.875 } },
    } };

    f['H'] = .{ .width = 9, .paths = &.{
        .{ .positions = &.{ .{ 0, 0 }, .{ 0, 8 } }, .angles = &.{0} },
        .{ .positions = &.{ .{ 6, 0 }, .{ 6, 8 } }, .angles = &.{0} },
        .{ .positions = &.{ .{ 0, 4 }, .{ 6, 4 } }, .angles = &.{0} },
    } };

    f['I'] = .{ .width = 4, .paths = &.{
        .{ .positions = &.{ .{ 1, 0 }, .{ 1, 8 } }, .angles = &.{0} },
    } };

    f['J'] = .{ .width = 7, .paths = &.{
        .{ .positions = &.{ .{ 3.5, 8 }, .{ 3.5, 2 }, .{ 1.5 - 2 * std.math.sqrt1_2, 2 - 2 * std.math.sqrt1_2 } }, .angles = &.{ 0, std.math.pi * 0.375 } },
    } };

    f['K'] = .{ .width = 8, .paths = &.{
        .{ .positions = &.{ .{ 0, 0 }, .{ 0, 8 } }, .angles = &.{0} },
        .{ .positions = &.{ .{ 0, 3 }, .{ 5, 8 } }, .angles = &.{0} },
        .{ .positions = &.{ .{ 2, 5 }, .{ 5, 0 } }, .angles = &.{0} },
    } };

    f['L'] = .{ .width = 7, .paths = &.{
        .{ .positions = &.{ .{ 4, 0 }, .{ 0, 0 }, .{ 0, 8 } }, .angles = &.{ 0, 0 } },
    } };

    f['M'] = .{ .width = 11, .paths = &.{
        .{ .positions = &.{ .{ 0, 0 }, .{ 0, 8 }, .{ 4, 2 }, .{ 8, 8 }, .{ 8, 0 } }, .angles = &.{ 0, 0, 0, 0 } },
    } };

    f['N'] = .{ .width = 9, .paths = &.{
        .{ .positions = &.{ .{ 0, 0 }, .{ 0, 8 }, .{ 6, 0 }, .{ 6, 8 } }, .angles = &.{ 0, 0, 0 } },
    } };

    f['O'] = .{ .width = 11, .paths = &.{
        .{ .positions = &.{ .{ 4, 0 }, .{ 4, 8 } }, .angles = &.{ std.math.pi * 0.5, std.math.pi * 0.5 } },
    } };

    f['P'] = .{ .width = 8, .paths = &.{
        .{ .positions = &.{ .{ 0, 0 }, .{ 0, 8 }, .{ 3, 8 }, .{ 3, 4 }, .{ 0, 4 } }, .angles = &.{ 0, 0, std.math.pi * 0.5, 0 } },
    } };

    f['Q'] = .{ .width = 11, .paths = &.{
        .{ .positions = &.{ .{ 4, 0 }, .{ 4, 8 } }, .angles = &.{ std.math.pi * 0.5, std.math.pi * 0.5 } },
        .{ .positions = &.{ .{ 5, 2 }, .{ 7, -1 } }, .angles = &.{0} },
    } };

    f['R'] = .{ .width = 8, .paths = &.{
        .{ .positions = &.{ .{ 0, 0 }, .{ 0, 8 }, .{ 3, 8 }, .{ 3, 4 }, .{ 0, 4 } }, .angles = &.{ 0, 0, std.math.pi * 0.5, 0 } },
        .{ .positions = &.{ .{ 3, 4 }, .{ 5, 0 } }, .angles = &.{0} },
    } };

    f['S'] = .{ .width = 8, .paths = &.{.{
        .positions = &.{
            .{ 2 - 2 * std.math.sqrt1_2, 2 - 2 * std.math.sqrt1_2 },
            .{ 2, 0 },
            .{ 2.5, 0 },
            .{ 2.5, 4 },
            .{ 2.5, 8 },
            .{ 3, 8 },
            .{ 3 + 2 * std.math.sqrt1_2, 6 + 2 * std.math.sqrt1_2 },
        },
        .angles = &.{ -std.math.pi * 0.125, 0, -std.math.pi * 0.5, std.math.pi * 0.5, 0, std.math.pi * 0.125 },
    }} };

    f['T'] = .{ .width = 9, .paths = &.{
        .{ .positions = &.{ .{ 3, 0 }, .{ 3, 8 } }, .angles = &.{0} },
        .{ .positions = &.{ .{ 0, 8 }, .{ 6, 8 } }, .angles = &.{0} },
    } };

    f['U'] = .{ .width = 8, .paths = &.{
        .{ .positions = &.{ .{ 0, 8 }, .{ 0, 2.5 }, .{ 5, 2.5 }, .{ 5, 8 } }, .angles = &.{ 0, -std.math.pi * 0.5, 0 } },
    } };

    f['V'] = .{ .width = 9, .paths = &.{
        .{ .positions = &.{ .{ 0, 8 }, .{ 3, 0 }, .{ 6, 8 } }, .angles = &.{ 0, 0 } },
    } };

    f['W'] = .{ .width = 13, .paths = &.{
        .{ .positions = &.{ .{ 0, 8 }, .{ 2, 0 }, .{ 5, 7 }, .{ 8, 0 }, .{ 10, 8 } }, .angles = &.{ 0, 0, 0, 0 } },
    } };

    f['X'] = .{ .width = 9, .paths = &.{
        .{ .positions = &.{ .{ 0, 0 }, .{ 6, 8 } }, .angles = &.{0} },
        .{ .positions = &.{ .{ 0, 8 }, .{ 6, 0 } }, .angles = &.{0} },
    } };

    f['X'] = .{ .width = 9, .paths = &.{
        .{ .positions = &.{ .{ 0, 0 }, .{ 6, 8 } }, .angles = &.{0} },
        .{ .positions = &.{ .{ 0, 8 }, .{ 6, 0 } }, .angles = &.{0} },
    } };

    f['Y'] = .{ .width = 9, .paths = &.{
        .{ .positions = &.{ .{ 0, 8 }, .{ 3, 4 }, .{ 6, 8 } }, .angles = &.{ 0, 0 } },
        .{ .positions = &.{ .{ 3, 0 }, .{ 3, 4 } }, .angles = &.{0} },
    } };

    f['Z'] = .{ .width = 9, .paths = &.{
        .{ .positions = &.{ .{ 0, 8 }, .{ 6, 8 }, .{ 0, 0 }, .{ 6, 0 } }, .angles = &.{ 0, 0, 0 } },
    } };

    f['0'] = .{ .width = 8, .paths = &.{
        .{ .positions = &.{ .{ 0, 2.5 }, .{ 0, 5.5 }, .{ 5, 5.5 }, .{ 5, 2.5 } }, .angles = &.{ 0, std.math.pi * 0.5, 0, std.math.pi * 0.5 } },
    } };

    f['1'] = .{ .width = 5, .paths = &.{
        .{ .positions = &.{ .{ 0, 7 }, .{ 2, 8 }, .{ 2, 0 } }, .angles = &.{ 0, 0 } },
    } };

    f['2'] = .{ .width = 7, .paths = &.{.{
        .positions = &.{
            .{ 1.5 - 2.5 * std.math.sqrt1_2, 5.5 + 2.5 * std.math.sqrt1_2 },
            .{ 1.5 + 2.5 * std.math.sqrt1_2, 5.5 - 2.5 * std.math.sqrt1_2 },
            .{ 0, 0 },
            .{ 4, 0 },
        },
        .angles = &.{ std.math.pi * 0.5, 0, 0 },
    }} };

    f['3'] = .{ .width = 7, .paths = &.{.{
        .positions = &.{
            .{ 1.5 - 1.5 * std.math.sqrt1_2, 6.5 + 1.5 * std.math.sqrt1_2 },
            .{ 1.5, 5 },
            .{ 1.5 - 2.5 * std.math.sqrt1_2, 2.5 - 2.5 * std.math.sqrt1_2 },
        },
        .angles = &.{ std.math.pi * 0.625, std.math.pi * 0.625 },
    }} };

    f['4'] = .{ .width = 8, .paths = &.{
        .{ .positions = &.{ .{ 5, 2 }, .{ 0, 2 }, .{ 4, 8 }, .{ 4, 0 } }, .angles = &.{ 0, 0, 0 } },
    } };

    f['5'] = .{ .width = 7, .paths = &.{
        .{ .positions = &.{
            .{ 4, 8 },
            .{ 1.5 - 2.5 * std.math.sqrt1_2, 8 },
            .{ 1.5 - 2.5 * std.math.sqrt1_2, 2.5 + 2.5 * std.math.sqrt1_2 },
            .{ 1.5 - 2.5 * std.math.sqrt1_2, 2.5 - 2.5 * std.math.sqrt1_2 },
        }, .angles = &.{ 0, 0, std.math.pi * 0.75 } },
    } };

    f['6'] = .{ .width = 8, .paths = &.{
        .{ .positions = &.{ .{ 0, 2.5 }, .{ 5, 2.5 } }, .angles = &.{ std.math.pi * 0.5, std.math.pi * 0.5 } },
        .{ .positions = &.{ .{ 3, 8 }, .{ 2.5 - 2.5 * std.math.sqrt1_2, 2.5 + 2.5 * std.math.sqrt1_2 } }, .angles = &.{0} },
    } };

    f['7'] = .{ .width = 8, .paths = &.{
        .{ .positions = &.{ .{ 0, 8 }, .{ 5, 8 }, .{ 1, 0 } }, .angles = &.{ 0, 0 } },
    } };

    f['8'] = .{ .width = 8, .paths = &.{
        .{ .positions = &.{ .{ 2.5, 0 }, .{ 2.5, 5 } }, .angles = &.{ std.math.pi * 0.5, std.math.pi * 0.5 } },
        .{ .positions = &.{ .{ 2.5, 5 }, .{ 2.5, 8 } }, .angles = &.{ std.math.pi * 0.5, std.math.pi * 0.5 } },
    } };

    f['9'] = .{ .width = 8, .paths = &.{
        .{ .positions = &.{ .{ 2.5, 3 }, .{ 2.5, 8 } }, .angles = &.{ std.math.pi * 0.5, std.math.pi * 0.5 } },
        .{ .positions = &.{ .{ 2, 0 }, .{ 2.5 + 2.5 * std.math.sqrt1_2, 5.5 - 2.5 * std.math.sqrt1_2 } }, .angles = &.{0} },
    } };

    f[' '] = .{ .width = 6 };

    f['.'] = .{ .width = 3, .paths = &.{
        .{ .positions = &.{.{ 0, 0 }}, .angles = &.{} },
    } };

    break :font f;
};
