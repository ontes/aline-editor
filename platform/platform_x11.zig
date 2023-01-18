const std = @import("std");
const common = @import("common.zig");
const x11 = @import("bindings/x11.zig");
const glx = @import("bindings/glx.zig");

pub var display: *x11.Display = undefined;

pub fn init() !void {
    if (x11.initThreads() == .err) return common.err;
    display = x11.openDisplay(null) orelse return common.err;
}

pub fn deinit() void {
    x11.closeDisplay(display);
    display = undefined;
}

pub const Window = struct {
    x11: x11.Window,

    pub fn create(position: [2]i32, size: [2]u32, name: [:0]const u8) !Window {
        const x11_window = x11.createSimpleWindow(display, x11.defaultRootWindow(display), //
            position[0], position[1], size[0], size[1], 0, 0, 0);

        x11.storeName(display, x11_window, name);

        x11.selectInput(display, x11_window, .{
            .key_press = true,
            .key_release = true,
            .button_press = true,
            .button_release = true,
            .crossing_enter = true,
            .crossing_leave = true,
            .motion = true,
            .structure = true,
            .focus = true,
        });

        // set up window close event
        if (x11.setWMProtocols(display, x11_window, &[1]x11.Atom{
            x11.internAtom(display, "WM_DELETE_WINDOW", .true),
        }, 1) == .err) return common.err;

        return Window{ .x11 = x11_window };
    }

    pub fn destroy(window: Window) void {
        x11.destroyWindow(display, window.x11);
    }

    pub fn show(window: Window) void {
        x11.mapWindow(display, window.x11);
    }

    pub fn getPosition(window: Window) ?[2]i32 {
        var attribs: x11.WindowAttributes = undefined;
        if (x11.getWindowAttributes(display, window.x11, &attribs) == .false)
            return null;
        return .{ attribs.x, attribs.y };
    }

    pub fn setPosition(window: Window, position: [2]i32) void {
        x11.moveWindow(display, window.x11, position[0], position[1]);
    }

    pub fn getSize(window: Window) ![2]u32 {
        var attribs: x11.WindowAttributes = undefined;
        if (x11.getWindowAttributes(display, window.x11, &attribs) == .err)
            return common.err;
        return .{ @intCast(u32, attribs.width), @intCast(u32, attribs.height) };
    }

    pub fn setSize(window: Window, size: [2]u32) void {
        x11.resizeWindow(display, window.x11, size[0], size[1]);
    }

    pub fn setName(window: Window, name: [*:0]const u8) void {
        x11.storeName(display, window.x11, name);
    }

    pub fn getMousePosition(window: Window) ?[2]i32 {
        var root: *Window = undefined;
        var child: *Window = undefined;
        var root_x: *c_int = undefined;
        var root_y: *c_int = undefined;
        var x: *c_int = undefined;
        var y: *c_int = undefined;
        var mask: *c_uint = undefined;
        if (x11.queryPointer(display, window.x11, &root, &child, &root_x, &root_y, &x, &y, &mask) == .false)
            return null;
        return .{ x, y };
    }

    pub fn setMousePosition(window: Window, pos: [2]i32) void {
        x11.warpPointer(display, null, window, 0, 0, 0, 0, pos[0], pos[1]);
    }

    pub fn grabMouse(window: Window) void {
        x11.grabPointer(display, window.x11, .true, 0, .grab_async, .grab_async, window.x11, null, 0);
    }

    pub fn ungrabMouse(window: Window) void {
        _ = window;
        x11.ungrabPointer(display, 0);
    }

    // pub fn hideMouse(window: Window) void {
    //     // create an empty cursor
    //     var color: XColor = undefined;
    //     var pixmap = XCreatePixmap(display, window, 1, 1, 1);
    //     defer XFreePixmap(display, pixmap);
    //     var cursor = XCreatePixmapCursor(display, pixmap, pixmap, &color, &color, 0, 0);
    //     defer XFreeCursor(display, cursor);
    //     XDefineCursor(display, window, cursor);
    // }

    // pub fn unhideMouse(window: Window) void {
    //     XUndefineCursor(display, window);
    // }
};

pub fn pollEvents(comptime callback: fn (event: common.Event, window: Window) anyerror!void) !void {
    var is_repeated = false;
    while (x11.pending(display) > 0) {
        var event: x11.Event = undefined;
        x11.nextEvent(display, &event);
        const window = Window{ .x11 = event.any.window };

        switch (event.type) {
            .key_press => {
                if (!is_repeated) {
                    if (keysymToKey(x11.lookupKeysym(&event.key, 0))) |key|
                        try callback(.{ .key_press = key }, window);
                }
                if (x11.filterEvent(&event, 0) == .false) {
                    var buffer = [1]u8{0};
                    const buffer_len = x11.lookupString(&event.key, &buffer, 1, null, null);
                    if (buffer_len == 1)
                        try callback(.{ .text_input = &.{buffer[0]} }, window);
                }
                is_repeated = false;
            },
            .key_release => {
                // skip auto-repeated key events
                if (x11.pending(display) > 0) {
                    var next_event: x11.Event = undefined;
                    x11.peekEvent(display, &next_event);
                    if (next_event.type == .key_press and next_event.key.keycode == event.key.keycode) {
                        is_repeated = true;
                    }
                }
                if (!is_repeated) {
                    if (keysymToKey(x11.lookupKeysym(&event.key, 0))) |key|
                        try callback(.{ .key_release = key }, window);
                }
            },
            .button_press => {
                if (buttonToKey(event.button.button)) |key|
                    try callback(.{ .key_press = key }, window);
                if (event.button.button == 4)
                    try callback(.{ .mouse_scroll = 1 }, window);
                if (event.button.button == 5)
                    try callback(.{ .mouse_scroll = -1 }, window);
            },
            .button_release => {
                if (buttonToKey(event.button.button)) |key|
                    try callback(.{ .key_release = key }, window);
            },
            .motion => {
                try callback(.{ .mouse_move = .{
                    event.motion.x,
                    event.motion.y,
                } }, window);
            },
            .crossing_enter => {
                if (event.crossing.mode == .normal)
                    try callback(.mouse_enter, window);
            },
            .crossing_leave => {
                if (event.crossing.mode == .normal)
                    try callback(.mouse_leave, window);
            },
            .focus_in => {
                if (event.focus.mode == .normal)
                    try callback(.window_focus, window);
            },
            .focus_out => {
                if (event.focus.mode == .normal)
                    try callback(.window_unfocus, window);
            },
            .configure => {
                // not working very well
                try callback(.{ .window_move = .{
                    event.configure.x,
                    event.configure.y,
                } }, window);
                try callback(.{ .window_resize = .{
                    @intCast(u32, event.configure.width),
                    @intCast(u32, event.configure.height),
                } }, window);
            },
            .client_message => {
                if (event.client_message.data.l[0] == x11.internAtom(display, "WM_DELETE_WINDOW", .true))
                    try callback(.window_close, window);
            },
            .mapping => {
                x11.refreshKeyboardMapping(&event.mapping);
            },
            else => {},
        }
    }
}

fn buttonToKey(button: c_uint) ?common.Key {
    return switch (button) {
        1 => .mouse_left,
        2 => .mouse_middle,
        3 => .mouse_right,
        8 => .mouse_back,
        9 => .mouse_forward,
        else => null,
    };
}

fn keysymToKey(keysym: c_ulong) ?common.Key {
    return switch (keysym) {
        0x0061 => .a,
        0x0062 => .b,
        0x0063 => .c,
        0x0064 => .d,
        0x0065 => .e,
        0x0066 => .f,
        0x0067 => .g,
        0x0068 => .h,
        0x0069 => .i,
        0x006a => .j,
        0x006b => .k,
        0x006c => .l,
        0x006d => .m,
        0x006e => .n,
        0x006f => .o,
        0x0070 => .p,
        0x0071 => .q,
        0x0072 => .r,
        0x0073 => .s,
        0x0074 => .t,
        0x0075 => .u,
        0x0076 => .v,
        0x0077 => .w,
        0x0078 => .x,
        0x0079 => .y,
        0x007a => .z,
        0x0030 => .n_0,
        0x0031 => .n_1,
        0x0032 => .n_2,
        0x0033 => .n_3,
        0x0034 => .n_4,
        0x0035 => .n_5,
        0x0036 => .n_6,
        0x0037 => .n_7,
        0x0038 => .n_8,
        0x0039 => .n_9,
        0xff0d => .enter,
        0xff1b => .escape,
        0xff08 => .backspace,
        0xff09 => .tab,
        0x0020 => .space,
        0x002d => .minus,
        0x003d => .equal,
        0x005b => .left_bracket,
        0x005d => .right_bracket,
        0x005c => .backslash,
        // .nonus_hash
        0x003b => .semicolon,
        0x0027 => .apostrophe,
        0x0060 => .grave,
        0x002c => .comma,
        0x002e => .period,
        0x002f => .slash,
        0xffe5 => .caps_lock,
        0xffbe => .f1,
        0xffbf => .f2,
        0xffc0 => .f3,
        0xffc1 => .f4,
        0xffc2 => .f5,
        0xffc3 => .f6,
        0xffc4 => .f7,
        0xffc5 => .f8,
        0xffc6 => .f9,
        0xffc7 => .f10,
        0xffc8 => .f11,
        0xffc9 => .f12,
        0xff61 => .print,
        0xff14 => .scroll_lock,
        0xff13 => .pause,
        0xff63 => .insert,
        0xff50 => .home,
        0xff55 => .page_up,
        0xffff => .delete,
        0xff57 => .end,
        0xff56 => .page_down,
        0xff53 => .right,
        0xff51 => .left,
        0xff54 => .down,
        0xff52 => .up,
        0xff7f => .num_lock,
        0xffaf => .kp_divide,
        0xffaa => .kp_multiply,
        0xffad => .kp_subtract,
        0xffab => .kp_add,
        0xff8d => .kp_enter,
        0xffb0 => .kp_n0,
        0xffb1 => .kp_n1,
        0xffb2 => .kp_n2,
        0xffb3 => .kp_n3,
        0xffb4 => .kp_n4,
        0xffb5 => .kp_n5,
        0xffb6 => .kp_n6,
        0xffb7 => .kp_n7,
        0xffb8 => .kp_n8,
        0xffb9 => .kp_n9,
        0xffae => .kp_decimal,
        // .nonus_backslash
        // .application
        0xffe3 => .left_ctrl,
        0xffe1 => .left_shift,
        0xffe9 => .left_alt,
        0xffeb => .left_super,
        0xffe4 => .right_ctrl,
        0xffe2 => .right_shift,
        0xffea => .right_alt,
        0xffec => .right_super,
        else => null,
    };
}

pub fn createGlContext(window: Window, color_size: u8, alpha_size: u8, depth_size: u8, stencil_size: u8, samples: u8) !GlContext {
    const fb_attribs = [_:0]c_int{
        glx.render_type,    glx.rgba_bit, //
        glx.drawable_type,  glx.window_bit,
        glx.x_renderable,   1,
        glx.x_visual_type,  glx.true_color,
        glx.doublebuffer,   1,
        glx.red_size,       color_size,
        glx.green_size,     color_size,
        glx.blue_size,      color_size,
        glx.alpha_size,     alpha_size,
        glx.depth_size,     depth_size,
        glx.stencil_size,   stencil_size,
        glx.sample_buffers, if (samples > 0) 1 else 0,
        glx.samples,        samples,
    };

    var fb_count: c_int = 0;
    const fb_configs = glx.chooseFBConfig(display, x11.defaultScreen(display), &fb_attribs, &fb_count);
    if (fb_count == 0) return common.err;
    const fb_config = fb_configs[0];
    x11.free(@ptrCast(*anyopaque, fb_configs));

    const glx_context = glx.createNewContext(display, fb_config, .rgba_type, null, .true) orelse return common.err;

    return .{ .window = window, .glx = glx_context };
}

pub const GlContext = struct {
    window: Window,
    glx: glx.Context,

    pub fn destroy(context: GlContext) void {
        glx.destroyContext(display, context.glx);
    }

    pub fn makeCurrent(context: GlContext) !void {
        if (glx.makeCurrent(display, context.window.x11, context.glx) == .false)
            return common.err;
    }

    pub fn swapBuffers(context: GlContext) void {
        glx.swapBuffers(display, context.window.x11);
    }
};
