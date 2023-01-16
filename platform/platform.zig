pub usingnamespace @import("common.zig");

pub const platform_win32 = @import("platform_win32.zig");
pub const platform_x11 = @import("platform_x11.zig");

pub usingnamespace switch (@import("builtin").target.os.tag) {
    .windows => platform_win32,
    .linux => platform_x11,
    else => @compileError("Target OS isn't supported"),
};

pub const imgui_impl = @import("imgui_impl.zig");
