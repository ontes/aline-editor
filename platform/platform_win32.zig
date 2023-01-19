const std = @import("std");
const win32 = @import("bindings/win32.zig");
const common = @import("common.zig");

pub var window_class = win32.WindowClassEx{
    .style = .{ .own_dc = true },
    .window_proc = &windowProc,
    .instance = undefined,
    .icon = null,
    .cursor = null,
    .background_brush = null,
    .menu_name = null,
    .class_name = "ALINE",
    .icon_small = null,
};

const Message = struct {
    window: Window,
    message_type: win32.MessageType,
    w_param: usize,
    l_param: isize,
};
var message_queue: std.ArrayList(Message) = undefined;

pub fn init() !void {
    message_queue = std.ArrayList(Message).init(std.heap.c_allocator);
    window_class.instance = @ptrCast(*win32.Instance, win32.getModuleHandle(null).?);
    if (win32.registerClassEx(&window_class) == 0) return common.err;
}

pub fn deinit() void {
    _ = win32.unregisterClass(window_class.class_name, window_class.instance);
    message_queue.deinit();
}

pub const Window = struct {
    win32: *win32.Window,

    pub fn create(position: [2]i32, size: [2]u32, name: [*:0]const u8) !Window {
        const win32_window = win32.createWindowEx(
            win32.WindowStyleEx.overlapped_window, // .{ .app_window = true }, // or overlapped_winow
            window_class.class_name,
            name,
            win32.WindowStyle.overlapped_window,
            position[0],
            position[1],
            @intCast(c_int, size[0]),
            @intCast(c_int, size[1]),
            null,
            null,
            window_class.instance,
            null,
        ) orelse return common.err;
        return .{ .win32 = win32_window };
    }

    pub fn destroy(window: Window) void {
        _ = win32.destroyWindow(window.win32);
    }

    pub fn show(window: Window) void {
        _ = win32.showWindow(window.win32, .show_normal);
    }

    pub fn getPosition(window: Window) ![2]i32 {
        var rect: win32.Rect = undefined;
        if (win32.getWindowRect(window.win32, &rect) == .err)
            return common.err;
        return .{ rect.left, rect.top };
    }

    pub fn getSize(window: Window) ![2]u32 {
        var rect: win32.Rect = undefined;
        if (win32.getWindowRect(window.win32, &rect) == .err)
            return common.err;
        return .{
            @intCast(u32, rect.right - rect.left),
            @intCast(u32, rect.bottom - rect.top),
        };
    }
};

pub fn pollEvents(comptime callback: fn (event: common.Event, window: Window) anyerror!void) !void {
    var message: win32.Message = undefined;
    while (win32.peekMessage(&message, null, 0, 0, .remove) == .true) {
        _ = win32.translateMessage(&message);
        _ = win32.dispatchMessage(&message);
    }

    while (message_queue.items.len > 0) {
        const msg = message_queue.orderedRemove(0);
        switch (msg.message_type) {
            .key_down, .sys_key_down => {
                // skip auto-repeated key events
                if ((msg.l_param >> 30) & 1 == 0) {
                    if (keycodeToKey(msg.w_param)) |key|
                        try callback(.{ .key_press = key }, msg.window);
                }
            },
            .key_up, .sys_key_up => {
                if (keycodeToKey(msg.w_param)) |key|
                    try callback(.{ .key_release = key }, msg.window);
            },
            .l_button_down, .m_button_down, .r_button_down, .x_button_down => {
                if (buttonToKey(msg.message_type, msg.w_param)) |key|
                    try callback(.{ .key_press = key }, msg.window);
            },
            .l_button_up, .m_button_up, .r_button_up, .x_button_up => {
                if (buttonToKey(msg.message_type, msg.w_param)) |key|
                    try callback(.{ .key_release = key }, msg.window);
            },
            .mouse_move => {
                try callback(.{
                    .mouse_move = .{
                        @truncate(i16, msg.l_param), // GET_X_LPARAM
                        @truncate(i16, msg.l_param >> 16), // GET_Y_LPARAM
                    },
                }, msg.window);
            },
            .mouse_wheel => {
                const delta = @truncate(i16, @bitCast(isize, msg.w_param) >> 16);
                try callback(.{ .mouse_scroll = @intCast(i8, @divTrunc(delta, 120)) }, msg.window);
            },
            .size => {
                try callback(.{ .window_resize = .{
                    @truncate(u16, @bitCast(usize, msg.l_param)),
                    @truncate(u16, @bitCast(usize, msg.l_param) >> 16),
                } }, msg.window);
            },
            .close => {
                try callback(.window_close, msg.window);
            },
            else => {},
        }
    }
}

fn windowProc(window: *win32.Window, message_type: win32.MessageType, w_param: usize, l_param: isize) callconv(.C) isize {
    message_queue.append(.{
        .window = .{ .win32 = window },
        .message_type = message_type,
        .w_param = w_param,
        .l_param = l_param,
    }) catch unreachable;
    return win32.defWindowProc(window, message_type, w_param, l_param);
}

fn buttonToKey(message_type: win32.MessageType, w_param: usize) ?common.Key {
    return switch (message_type) {
        .l_button_down, .l_button_up => .mouse_left,
        .m_button_down, .m_button_up => .mouse_middle,
        .r_button_down, .r_button_up => .mouse_right,
        .x_button_down, .x_button_up => return if (@truncate(u16, w_param >> 16) == 1) .mouse_back else .mouse_forward,
        else => null,
    };
}

fn keycodeToKey(w_param: usize) ?common.Key {
    return switch (w_param) {
        0x41 => .a,
        0x42 => .b,
        0x43 => .c,
        0x44 => .d,
        0x45 => .e,
        0x46 => .f,
        0x47 => .g,
        0x48 => .h,
        0x49 => .i,
        0x4a => .j,
        0x4b => .k,
        0x4c => .l,
        0x4d => .m,
        0x4e => .n,
        0x4f => .o,
        0x50 => .p,
        0x51 => .q,
        0x52 => .r,
        0x53 => .s,
        0x54 => .t,
        0x55 => .u,
        0x56 => .v,
        0x57 => .w,
        0x58 => .x,
        0x59 => .y,
        0x5a => .z,
        0x30 => .n_0,
        0x31 => .n_1,
        0x32 => .n_2,
        0x33 => .n_3,
        0x34 => .n_4,
        0x35 => .n_5,
        0x36 => .n_6,
        0x37 => .n_7,
        0x38 => .n_8,
        0x39 => .n_9,
        0x0d => .enter,
        0x1b => .escape,
        0x08 => .backspace,
        0x09 => .tab,
        0x20 => .space,
        0xbd => .minus,
        0xbb => .equal,
        0xdb => .left_bracket,
        0xdd => .right_bracket,
        0xdc => .backslash,
        0xdf => .nonus_hash,
        0xba => .semicolon,
        0xde => .apostrophe,
        0xc0 => .grave,
        0xbc => .comma,
        0xbe => .period,
        0xbf => .slash,
        0x14 => .caps_lock,
        0x70 => .f1,
        0x71 => .f2,
        0x72 => .f3,
        0x73 => .f4,
        0x74 => .f5,
        0x75 => .f6,
        0x76 => .f7,
        0x77 => .f8,
        0x78 => .f9,
        0x79 => .f10,
        0x7a => .f11,
        0x7b => .f12,
        0x2c => .print,
        0x91 => .scroll_lock,
        0x13 => .pause,
        0x2d => .insert,
        0x24 => .home,
        0x21 => .page_up,
        0x2e => .delete,
        0x23 => .end,
        0x22 => .page_down,
        0x27 => .right,
        0x25 => .left,
        0x28 => .down,
        0x26 => .up,
        0x90 => .num_lock,
        0x6f => .kp_divide,
        0x6a => .kp_multiply,
        0x6d => .kp_subtract,
        0x6b => .kp_add,
        0x6c => .kp_enter,
        0x60 => .kp_n0,
        0x61 => .kp_n1,
        0x62 => .kp_n2,
        0x63 => .kp_n3,
        0x64 => .kp_n4,
        0x65 => .kp_n5,
        0x66 => .kp_n6,
        0x67 => .kp_n7,
        0x68 => .kp_n8,
        0x69 => .kp_n9,
        0x6e => .kp_decimal,
        0xe2 => .nonus_backslash,
        0x5d => .application,
        0x11, 0xa2 => .left_ctrl,
        0x10, 0xa0 => .left_shift,
        0x12, 0xa4 => .left_alt,
        0x5b => .left_super,
        0xa3 => .right_ctrl,
        0xa1 => .right_shift,
        0xa5 => .right_alt,
        0x5c => .right_super,
        else => null,
    };
}

pub const GlContext = opaque {
    // pub fn create(window: Window, color_size: u8, alpha_size: u8, depth_size: u8, stencil_size: u8, samples: u8) !*GlContext {
    //     _ = samples;

    //     var pixel_format_desc = std.mem.zeroes(PIXELFORMATDESCRIPTOR);
    //     pixel_format_desc.nSize = @sizeOf(PIXELFORMATDESCRIPTOR);
    //     pixel_format_desc.nVersion = 1;
    //     pixel_format_desc.dwFlags = PFD_DRAW_TO_WINDOW | PFD_SUPPORT_OPENGL | PFD_GENERIC_ACCELERATED | PFD_DOUBLEBUFFER; // | PFD_DRAW_TO_BITMAP
    //     pixel_format_desc.iPixelType = PFD_TYPE_RGBA;
    //     pixel_format_desc.cColorBits = 3 * color_size;
    //     pixel_format_desc.cAlphaBits = alpha_size;
    //     pixel_format_desc.cDepthBits = depth_size;
    //     pixel_format_desc.cStencilBits = stencil_size;

    //     const pixel_format = ChoosePixelFormat(GetDC(window), &pixel_format_desc);
    //     if (pixel_format == 0) return common.err;
    //     _ = SetPixelFormat(GetDC(window), pixel_format, &pixel_format_desc);

    //     return wglCreateContext(GetDC(window));
    // }

    // pub fn destroy(context: *GlContext) void {
    //     _ = wglDeleteContext(context);
    // }

    // pub fn makeCurrent(context: *GlContext, window: Window) !void {
    //     if (wglMakeCurrent(GetDC(window), context) == 0) return common.err;
    // }

    // pub fn swapBuffers(window: Window) void {
    //     _ = SwapBuffers(GetDC(window));
    // }
};
