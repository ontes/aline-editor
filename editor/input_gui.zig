const std = @import("std");
const platform = @import("platform");
const webgpu = @import("webgpu");
const imgui = @import("imgui");
const imgui_impl_wgpu = @import("imgui_impl_wgpu");

const editor = @import("editor.zig");
const operations = @import("operations.zig");
const grabs = @import("grabs.zig");

var last_time: u64 = 0;

pub fn init(device: *webgpu.Device) void {
    _ = imgui.createContext(null);
    imgui.styleColorsLight(null);
    _ = imgui_impl_wgpu.init(device, 3, .bgra8_unorm, .undef);

    const io = imgui.getIO();
    io.backend_platform_name = "imgui_impl_aline";
    io.ini_filename = null;
    last_time = @intCast(u64, std.time.microTimestamp());
}

pub fn deinit() void {
    imgui_impl_wgpu.shutdown();
    imgui.destroyContext(null);
}

pub fn onFrame() !void {
    const io = imgui.getIO();
    const time = @intCast(u64, std.time.microTimestamp());
    io.delta_time = @intToFloat(f32, time - last_time) / std.time.us_per_s;
    last_time = time;

    imgui_impl_wgpu.newFrame();
    imgui.newFrame();

    if (editor.operation) |*any_operation| {
        imgui.setNextWindowSize(.{ .x = 256, .y = 256 }, .once);
        var open = true;
        if (imgui.begin("Operation", &open, .{})) switch (any_operation.*) {
            .AddPoint => |*op| {
                imgui.text("Add Point");

                if (imgui.inputFloat2("position", &op.position[0], null, .{}))
                    try editor.updateOperation();
                if (imgui.button("grab position", .{ .x = 0, .y = 0 }))
                    editor.grab = .{ .Position = grabs.Position.init(&op.position) };
            },
            .Append => |*op| {
                imgui.text("Append");

                if (imgui.inputFloat2("position", &op.position[0], null, .{}))
                    try editor.updateOperation();
                if (imgui.button("grab position", .{ .x = 0, .y = 0 }))
                    editor.grab = .{ .Position = grabs.Position.init(&op.position) };

                if (imgui.inputFloat("angle", &op.angle, 0, 0, null, .{}))
                    try editor.updateOperation();
                if (imgui.button("grab angle", .{ .x = 0, .y = 0 }))
                    editor.grab = .{ .Angle = grabs.Angle.init(&op.angle, op._pos_a, op.position) };
            },
            .Connect => |*op| {
                imgui.text("Connect");

                if (imgui.inputFloat("angle", &op.angle, 0, 0, null, .{}))
                    try editor.updateOperation();
                if (imgui.button("grab angle", .{ .x = 0, .y = 0 }))
                    editor.grab = .{ .Angle = grabs.Angle.init(&op.angle, op._pos_a, op._pos_b) };
            },
            .Move => |*op| {
                imgui.text("Move");

                if (imgui.inputFloat2("offset", &op.offset[0], null, .{}))
                    try editor.updateOperation();
                if (imgui.button("grab offset", .{ .x = 0, .y = 0 }))
                    editor.grab = .{ .Offset = grabs.Offset.init(&op.offset) };
            },
            .Remove => {
                imgui.text("Remove");
            },
            .ChangeAngle => |*op| {
                imgui.text("Change Angle");

                if (imgui.inputFloat("angle", &op.angle, 0, 0, null, .{}))
                    try editor.updateOperation();
                if (imgui.button("grab angle", .{ .x = 0, .y = 0 }))
                    editor.grab = .{ .Angle = grabs.Angle.init(&op.angle, op._pos_a, op._pos_b) };
            },
        };
        if (!open) editor.operation = null;
        imgui.end();
    }

    if (imgui.beginPopupContextVoid("context menu", .{ .mouse_button_right = true })) {
        if (operations.AddPoint.init(editor.history.get().*)) |op| {
            if (imgui.menuItem("Add Point", "A", null, true)) {
                try editor.setOperation(.{ .AddPoint = op });
                editor.grab = .{ .Position = grabs.Position.init(&editor.operation.?.AddPoint.position) };
            }
        }
        if (operations.Append.init(editor.history.get().*)) |op| {
            if (imgui.menuItem("Append", "A", null, true)) {
                try editor.setOperation(.{ .Append = op });
                editor.grab = .{ .Position = grabs.Position.init(&editor.operation.?.Append.position) };
            }
        }
        if (operations.Connect.init(editor.history.get().*)) |op| {
            if (imgui.menuItem("Connect", "C", null, true)) {
                try editor.setOperation(.{ .Connect = op });
            }
        }
        if (operations.Move.init(editor.history.get().*)) |op| {
            if (imgui.menuItem("Move", "G", null, true)) {
                try editor.setOperation(.{ .Move = op });
                editor.grab = .{ .Offset = grabs.Offset.init(&editor.operation.?.Move.offset) };
            }
        }
        if (operations.ChangeAngle.init(editor.history.get().*)) |op| {
            if (imgui.menuItem("Change Angle", "D", null, true)) {
                try editor.setOperation(.{ .ChangeAngle = op });
                editor.grab = .{ .Angle = grabs.Angle.init(&editor.operation.?.ChangeAngle.angle, editor.operation.?.ChangeAngle._pos_a, editor.operation.?.ChangeAngle._pos_b) };
            }
        }
        if (operations.Remove.init(editor.history.get().*)) |op| {
            if (imgui.menuItem("Remove", "DEL", null, true)) {
                try editor.setOperation(.{ .Remove = op });
            }
        }
        imgui.endPopup();
    }

    imgui.render();
}

pub fn isGrabbed() bool {
    const io = imgui.getIO();
    return io.want_capture_mouse or io.want_capture_keyboard;
}

pub fn render(pass: *webgpu.RenderPassEncoder) void {
    imgui_impl_wgpu.renderDrawData(imgui.getDrawData().?, pass);
}

pub fn onEvent(event: platform.Event) void {
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
        .text_input => |text| {
            io.addInputCharactersUTF8(text.ptr);
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

fn toImguiMouseButton(key: platform.Key) ?imgui.MouseButton {
    return switch (key) {
        .mouse_left => .left,
        .mouse_right => .right,
        .mouse_middle => .middle,
        .mouse_back => @intToEnum(imgui.MouseButton, 3),
        .mouse_forward => @intToEnum(imgui.MouseButton, 4),
        else => null,
    };
}

fn toImguiKey(key: platform.Key) ?imgui.Key {
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

fn toImguiModKey(key: platform.Key) ?imgui.Key {
    return switch (key) {
        .left_ctrl, .right_ctrl => .mod_ctrl,
        .left_shift, .right_shift => .mod_shift,
        .left_alt, .right_alt => .mod_alt,
        .left_super, .right_super => .mod_super,
        else => null,
    };
}
