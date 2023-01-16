const std = @import("std");
const common = @import("common.zig");
const imgui = @import("imgui");

var last_time: u64 = 0;

pub fn init() void {
    const io = imgui.getIO();
    io.ini_filename = null;
    io.backend_platform_name = "imgui_impl_aline";
    last_time = @intCast(u64, std.time.microTimestamp());
}

pub fn shutdown() void {
    const io = imgui.getIO();
    io.backend_platform_name = null;
}

pub fn handleEvent(event: common.Event) void {
    const io = imgui.getIO();
    switch (event) {
        .key_press, .key_release => |key| {
            if (toImguiMouseButton(key)) |imgui_mouse_button|
                io.addMouseButtonEvent(imgui_mouse_button, event == .key_press);
            if (toImguiKey(key)) |imgui_key|
                io.addKeyEvent(imgui_key, event == .key_press);
            if (toImguiModKey(key)) |imgui_key|
                io.addKeyEvent(imgui_key, event == .key_press);
        },
        .mouse_move => |pos| {
            io.addMousePosEvent(@intToFloat(f32, pos[0]), @intToFloat(f32, pos[1]));
        },
        .mouse_scroll => |offset| {
            io.addMouseWheelEvent(0, @intToFloat(f32, offset));
        },
        .window_resize => |size| {
            io.display_size = .{ .x = @intToFloat(f32, size[0]), .y = @intToFloat(f32, size[1]) };
        },
        .window_focus, .window_unfocus => {
            io.addFocusEvent(event == .window_focus);
        },
        else => {},
    }
}

pub fn newFrame() void {
    const io = imgui.getIO();
    const time = @intCast(u64, std.time.microTimestamp());
    io.delta_time = @intToFloat(f32, time - last_time) / std.time.us_per_s;
    last_time = time;
}

fn toImguiMouseButton(key: common.Key) ?imgui.MouseButton {
    return switch (key) {
        .mouse_left => .left,
        .mouse_right => .right,
        .mouse_middle => .middle,
        .mouse_back => @intToEnum(imgui.MouseButton, 3),
        .mouse_forward => @intToEnum(imgui.MouseButton, 4),
        else => null,
    };
}

fn toImguiKey(key: common.Key) ?imgui.Key {
    return switch (key) {
        .a => .a,
        .b => .b,
        .c => .c,
        .d => .d,
        .e => .e,
        .f => .f,
        .g => .g,
        .h => .h,
        .i => .i,
        .j => .j,
        .k => .k,
        .l => .l,
        .m => .m,
        .n => .n,
        .o => .o,
        .p => .p,
        .q => .q,
        .r => .r,
        .s => .s,
        .t => .t,
        .u => .u,
        .v => .v,
        .w => .w,
        .x => .x,
        .y => .y,
        .z => .z,
        .n_1 => .n_1,
        .n_2 => .n_2,
        .n_3 => .n_3,
        .n_4 => .n_4,
        .n_5 => .n_5,
        .n_6 => .n_6,
        .n_7 => .n_7,
        .n_8 => .n_8,
        .n_9 => .n_9,
        .n_0 => .n_0,
        .enter => .enter,
        .escape => .escape,
        .backspace => .backspace,
        .tab => .tab,
        .space => .space,
        .minus => .minus,
        .equal => .equal,
        .left_bracket => .left_bracket,
        .right_bracket => .right_bracket,
        .backslash => .backslash,
        // .nonus_hash => .nonus_hash,
        .semicolon => .semicolon,
        .apostrophe => .apostrophe,
        // .grave => .grave,
        .comma => .comma,
        .period => .period,
        .slash => .slash,
        .caps_lock => .caps_lock,
        .f1 => .f1,
        .f2 => .f2,
        .f3 => .f3,
        .f4 => .f4,
        .f5 => .f5,
        .f6 => .f6,
        .f7 => .f7,
        .f8 => .f8,
        .f9 => .f9,
        .f10 => .f10,
        .f11 => .f11,
        .f12 => .f12,
        // .print => .print,
        .scroll_lock => .scroll_lock,
        .pause => .pause,
        .insert => .insert,
        .home => .home,
        .page_up => .page_up,
        .delete => .delete,
        .end => .end,
        .page_down => .page_down,
        .right => .right_arrow,
        .left => .left_arrow,
        .down => .down_arrow,
        .up => .up_arrow,
        .left_ctrl => .left_ctrl,
        .left_shift => .left_shift,
        .left_alt => .left_alt,
        .left_super => .left_super,
        .right_ctrl => .right_ctrl,
        .right_shift => .right_shift,
        .right_alt => .right_alt,
        .right_super => .right_super,
        else => null,
    };
}

fn toImguiModKey(key: common.Key) ?imgui.Key {
    return switch (key) {
        .left_ctrl, .right_ctrl => .mod_ctrl,
        .left_shift, .right_shift => .mod_shift,
        .left_alt, .right_alt => .mod_alt,
        .left_super, .right_super => .mod_super,
        else => null,
    };
}
