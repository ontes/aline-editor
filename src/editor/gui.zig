const std = @import("std");
const math = @import("math");
const platform = @import("platform");
const webgpu = @import("webgpu");
const imgui = @import("imgui");
const imgui_impl_wgpu = @import("imgui_impl_wgpu");

const editor = @import("editor.zig");

var last_time: u128 = 0;
var preferences_open: bool = false;

pub fn init(device: *webgpu.Device) void {
    _ = imgui.createContext(null);
    imgui.styleColorsLight(null);
    _ = imgui_impl_wgpu.init(device, 3, .bgra8_unorm, .undef);

    const io = imgui.getIO();
    io.backend_platform_name = "imgui_impl_aline";
    io.ini_filename = null;
    last_time = @intCast(u128, std.time.nanoTimestamp());
}

pub fn deinit() void {
    imgui_impl_wgpu.shutdown();
    imgui.destroyContext(null);
}

pub fn onFrame() !void {
    const io = imgui.getIO();
    const time = @intCast(u128, std.time.nanoTimestamp());
    io.delta_time = @intToFloat(f32, time - last_time) / std.time.ns_per_s;
    last_time = time;

    imgui_impl_wgpu.newFrame();
    imgui.newFrame();

    imgui.setNextWindowPos(.{ .x = 64, .y = 64 }, .once, .{ .x = 0, .y = 0 });
    imgui.setNextWindowSize(.{ .x = 256, .y = 256 }, .once);
    if (imgui.begin("Paths", null, .{}) and imgui.beginListBox("path list box", .{ .x = -1, .y = -1 })) {
        const is = editor.history.get();
        for (is.image.props.items(.name)) |name, index| {
            imgui.pushIDInt(@intCast(c_int, index));
            if (imgui.selectable(@ptrCast([*:0]const u8, &name), is.isPathPartiallySelected(index), .{}, .{ .x = 0, .y = 0 }) or
                (imgui.isItemHovered(.{ .allow_when_blocked_by_popup = true }) and imgui.isMouseClicked(.right, false) and !is.isPathSelected(index)))
            {
                try editor.finishOperation();
                if (!imgui.isKeyDown(.mod_shift))
                    is.deselectAll();
                try is.togglePath(index);
                editor.should_draw_helper = true;
            }
            if ((imgui.isItemHovered(.{}) and imgui.isMouseDoubleClicked(.left))) {
                try editor.setOperation(.{ .Rename = editor.Operation.Rename.init(editor.getIS()).? });
            }
            imgui.popID();
        }
        imgui.endListBox();
        if (imgui.beginPopupContextItem("context menu", .{ .mouse_button_right = true })) {
            try editor.finishOperation();
            if (editor.Operation.Rename.init(editor.getIS())) |op| {
                if (imgui.menuItem("Rename", "F2", false, true)) {
                    try editor.setOperation(.{ .Rename = op });
                }
            }
            if (editor.Operation.ChangeStyle.init(editor.getIS())) |op| {
                if (imgui.menuItem("Change Style", "TAB", false, true)) {
                    try editor.setOperation(.{ .ChangeStyle = op });
                }
            }
            if (editor.Operation.Remove.init(editor.getIS())) |op| {
                if (imgui.menuItem("Remove", "DEL", false, true)) {
                    try editor.setOperation(.{ .Remove = op });
                }
            }
            imgui.endPopup();
        }
    }
    imgui.end();

    if (editor.operation) |*any_operation| {
        imgui.setNextWindowPos(.{ .x = 64, .y = 384 }, .once, .{ .x = 0, .y = 0 });
        imgui.setNextWindowSize(.{ .x = 256, .y = 256 }, .once);
        var open = true;
        if (imgui.begin("Operation", &open, .{})) switch (any_operation.*) {
            .Rename => |*op| {
                imgui.text("Rename");

                if (editor.operation_is_new) {
                    imgui.setKeyboardFocusHere(0);
                    editor.operation_is_new = false;
                }
                const name_max_len = @typeInfo(@import("Image.zig").Path.Name).Array.len;
                if (imgui.inputText("##name", &op.name, name_max_len - 1, .{}, null, null))
                    try editor.updateOperation();
            },
            .ChangeStyle => |*op| {
                imgui.text("Change Style");

                imgui.beginDisabled(!op.enable_fill_color);
                if (imgui.colorEdit4("fill color", &op.style.fill_color, .{}))
                    try editor.updateOperation();
                if (imgui.isItemHovered(.{ .allow_when_disabled = true }) and imgui.isMouseClicked(.left, false))
                    op.enable_fill_color = true;
                imgui.endDisabled();

                imgui.beginDisabled(!op.enable_stroke_color);
                if (imgui.colorEdit4("stroke color", &op.style.stroke_color, .{}))
                    try editor.updateOperation();
                if (imgui.isItemHovered(.{ .allow_when_disabled = true }) and imgui.isMouseClicked(.left, false))
                    op.enable_stroke_color = true;
                imgui.endDisabled();

                imgui.beginDisabled(!op.enable_stroke_width);
                if (imgui.inputFloat("stroke width", &op.style.stroke.width, 0, 0, null, .{}))
                    try editor.updateOperation();
                if (imgui.isItemHovered(.{ .allow_when_disabled = true }) and imgui.isMouseClicked(.left, false))
                    op.enable_stroke_width = true;
                imgui.endDisabled();

                imgui.beginDisabled(!op.enable_stroke_cap);
                if (imgui.beginCombo("stroke cap", @tagName(op.style.stroke.cap), .{})) {
                    inline for (@typeInfo(math.Stroke.CapStyle).Enum.fields) |field| {
                        const tag = @field(math.Stroke.CapStyle, field.name);
                        if (imgui.selectable(field.name ++ "", op.style.stroke.cap == tag, .{}, .{ .x = 0, .y = 0 })) {
                            op.style.stroke.cap = tag;
                            try editor.updateOperation();
                        }
                    }
                    imgui.endCombo();
                }
                if (imgui.isItemHovered(.{ .allow_when_disabled = true }) and imgui.isMouseClicked(.left, false))
                    op.enable_stroke_cap = true;
                imgui.endDisabled();
            },
            .AddPoint => |*op| {
                imgui.text("Add Point");

                if (imgui.inputFloat2("position", &op.position[0], null, .{}))
                    try editor.updateOperation();
                if (imgui.isItemHovered(.{}) and imgui.isMouseDoubleClicked(.left))
                    editor.capture = .{ .Position = editor.Capture.Position.init(&op.position) };
            },
            .Append => |*op| {
                imgui.text("Append");

                if (imgui.inputFloat2("position", &op.position[0], null, .{}))
                    try editor.updateOperation();
                if (imgui.isItemHovered(.{}) and imgui.isMouseDoubleClicked(.left))
                    editor.capture = .{ .Position = editor.Capture.Position.init(&op.position) };

                var angle_deg = std.math.radiansToDegrees(f32, op.angle);
                if (imgui.inputFloat("angle", &angle_deg, 0, 0, null, .{})) {
                    op.angle = std.math.degreesToRadians(f32, angle_deg);
                    try editor.updateOperation();
                }
                if (imgui.isItemHovered(.{}) and imgui.isMouseDoubleClicked(.left))
                    editor.capture = .{ .ArcAngle = editor.Capture.ArcAngle.init(&op.angle, op._pos_a, op.position) };
            },
            .Connect => |*op| {
                imgui.text("Connect");

                var angle_deg = std.math.radiansToDegrees(f32, op.angle);
                if (imgui.inputFloat("angle", &angle_deg, 0, 0, null, .{})) {
                    op.angle = std.math.degreesToRadians(f32, angle_deg);
                    try editor.updateOperation();
                }
                if (imgui.isItemHovered(.{}) and imgui.isMouseDoubleClicked(.left))
                    editor.capture = .{ .ArcAngle = editor.Capture.ArcAngle.init(&op.angle, op._pos_a, op._pos_b) };
            },
            .Move => |*op| {
                imgui.text("Move");

                if (imgui.inputFloat2("offset", &op.offset[0], null, .{}))
                    try editor.updateOperation();
                if (imgui.isItemHovered(.{}) and imgui.isMouseDoubleClicked(.left))
                    editor.capture = .{ .Offset = editor.Capture.Offset.init(&op.offset) };
            },
            .Rotate => |*op| {
                imgui.text("Rotate");

                if (imgui.inputFloat2("origin", &op.origin[0], null, .{}))
                    try editor.updateOperation();
                if (imgui.isItemHovered(.{}) and imgui.isMouseDoubleClicked(.left))
                    editor.capture = .{ .Position = editor.Capture.Position.init(&op.origin) };

                var angle_deg = std.math.radiansToDegrees(f32, op.angle);
                if (imgui.inputFloat("angle", &angle_deg, 0, 0, null, .{})) {
                    op.angle = std.math.degreesToRadians(f32, angle_deg);
                    try editor.updateOperation();
                }
                if (imgui.isItemHovered(.{}) and imgui.isMouseDoubleClicked(.left))
                    editor.capture = .{ .Angle = editor.Capture.Angle.init(&op.angle, op.origin) };
            },
            .Scale => |*op| {
                imgui.text("Scale");

                if (imgui.inputFloat2("origin", &op.origin[0], null, .{}))
                    try editor.updateOperation();
                if (imgui.isItemHovered(.{}) and imgui.isMouseDoubleClicked(.left))
                    editor.capture = .{ .Position = editor.Capture.Position.init(&op.origin) };

                _ = imgui.checkbox("lock aspect ratio", &op.lock_aspect);

                if (op.lock_aspect) {
                    if (imgui.inputFloat("scale", &op.scale[0], 0, 0, null, .{})) {
                        op.scale[1] = op.scale[0];
                        try editor.updateOperation();
                    }
                } else {
                    if (imgui.inputFloat2("scale", &op.scale[0], null, .{}))
                        try editor.updateOperation();
                }
                if (imgui.isItemHovered(.{}) and imgui.isMouseDoubleClicked(.left))
                    editor.capture = .{ .Scale = editor.Capture.Scale.init(&op.scale, op.origin, op.lock_aspect) };
            },
            .Remove => |*op| {
                imgui.text("Remove");

                if (imgui.checkbox("remove single nodes", &op.remove_single_nodes))
                    try editor.updateOperation();
            },
            .ChangeAngle => |*op| {
                imgui.text("Change Angle");

                var angle_deg = std.math.radiansToDegrees(f32, op.angle);
                if (imgui.inputFloat("##angle", &angle_deg, 0, 0, null, .{})) {
                    op.angle = std.math.degreesToRadians(f32, angle_deg);
                    try editor.updateOperation();
                }
                if (imgui.isItemHovered(.{}) and imgui.isMouseDoubleClicked(.left))
                    editor.capture = .{ .ArcAngle = editor.Capture.ArcAngle.init(&op.angle, op._pos_a, op._pos_b) };
            },
            .Order => |*op| {
                imgui.text("Order");

                var offset = @intCast(c_int, op.offset);
                if (imgui.inputInt("##offset", &offset, 1, 100, .{})) {
                    const limit = editor.Operation.Order.getLimit(editor.getIS());
                    op.offset = @max(@min(offset, limit), -limit);
                    try editor.updateOperation();
                }
            },
        };
        imgui.end();
        if (!open) editor.operation = null;
    }

    if (imgui.beginPopupContextVoid("context menu", .{ .mouse_button_right = true })) {
        try editor.finishOperation();
        if (editor.Operation.ChangeStyle.init(editor.getIS())) |op| {
            if (imgui.menuItem("Change Style", "TAB", false, true)) {
                try editor.setOperation(.{ .ChangeStyle = op });
            }
        }
        if (editor.Operation.AddPoint.init(editor.getIS())) |op| {
            if (imgui.menuItem("Add Point", "A", false, true)) {
                try editor.setOperation(.{ .AddPoint = op });
                editor.capture = .{ .Position = editor.Capture.Position.init(&editor.operation.?.AddPoint.position) };
            }
        }
        if (editor.Operation.Append.init(editor.getIS())) |op| {
            if (imgui.menuItem("Append", "A", false, true)) {
                try editor.setOperation(.{ .Append = op });
                editor.capture = .{ .Position = editor.Capture.Position.init(&editor.operation.?.Append.position) };
            }
        }
        if (editor.Operation.Connect.init(editor.getIS())) |op| {
            if (imgui.menuItem("Connect", "C", false, true)) {
                try editor.setOperation(.{ .Connect = op });
            }
        }
        if (editor.Operation.Move.init(editor.getIS())) |op| {
            if (imgui.menuItem("Move", "G", false, true)) {
                try editor.setOperation(.{ .Move = op });
                editor.capture = .{ .Offset = editor.Capture.Offset.init(&editor.operation.?.Move.offset) };
            }
        }
        if (editor.Operation.Rotate.init(editor.getIS())) |op_| {
            var op = op_;
            if (imgui.beginMenu("Rotate", true)) {
                if (imgui.menuItem("Rotate CW 90°", null, false, true)) {
                    op.angle = std.math.degreesToRadians(f32, -90);
                    try editor.setOperation(.{ .Rotate = op });
                }
                if (imgui.menuItem("Rotate CCW 90°", null, false, true)) {
                    op.angle = std.math.degreesToRadians(f32, 90);
                    try editor.setOperation(.{ .Rotate = op });
                }
                if (imgui.menuItem("Rotate 180°", null, false, true)) {
                    op.angle = std.math.degreesToRadians(f32, 180);
                    try editor.setOperation(.{ .Rotate = op });
                }
                imgui.endMenu();
            }
            if (imgui.isItemClicked(.left)) {
                try editor.setOperation(.{ .Rotate = op });
                editor.capture = .{ .Angle = editor.Capture.Angle.init(&editor.operation.?.Rotate.angle, op.origin) };
            }
        }
        if (editor.Operation.Scale.init(editor.getIS())) |op_| {
            var op = op_;
            if (imgui.beginMenu("Scale", true)) {
                if (imgui.menuItem("Flip horizontally", null, false, true)) {
                    op.lock_aspect = false;
                    op.scale[0] = -1;
                    try editor.setOperation(.{ .Scale = op });
                }
                if (imgui.menuItem("Flip vertically", null, false, true)) {
                    op.lock_aspect = false;
                    op.scale[1] = -1;
                    try editor.setOperation(.{ .Scale = op });
                }
                if (imgui.menuItem("Transpose", null, false, true)) {
                    op.scale[0] = -1;
                    op.scale[1] = -1;
                    try editor.setOperation(.{ .Scale = op });
                }
                imgui.endMenu();
            }
            if (imgui.isItemClicked(.left)) {
                try editor.setOperation(.{ .Scale = op });
                editor.capture = .{ .Scale = editor.Capture.Scale.init(&editor.operation.?.Scale.scale, op.origin, op.lock_aspect) };
            }
        }
        if (editor.Operation.ChangeAngle.init(editor.getIS())) |op| {
            if (imgui.menuItem("Change ArcAngle", "D", false, true)) {
                try editor.setOperation(.{ .ChangeAngle = op });
                editor.capture = .{ .ArcAngle = editor.Capture.ArcAngle.init(&editor.operation.?.ChangeAngle.angle, editor.operation.?.ChangeAngle._pos_a, editor.operation.?.ChangeAngle._pos_b) };
            }
        }
        if (editor.Operation.Order.init(editor.getIS())) |op_| {
            var op = op_;
            if (imgui.beginMenu("Order", true)) {
                if (imgui.menuItem("Bring to front", "SHIFT+UP", false, true)) {
                    op.offset = editor.Operation.Order.getLimit(editor.getIS());
                    try editor.setOperation(.{ .Order = op });
                }
                if (imgui.menuItem("Bring forward", "UP", false, true)) {
                    op.offset = 1;
                    try editor.setOperation(.{ .Order = op });
                }
                if (imgui.menuItem("Send backward", "DOWN", false, true)) {
                    op.offset = -1;
                    try editor.setOperation(.{ .Order = op });
                }
                if (imgui.menuItem("Send to back", "SHIFT+DOWN", false, true)) {
                    op.offset = -editor.Operation.Order.getLimit(editor.getIS());
                    try editor.setOperation(.{ .Order = op });
                }
                imgui.endMenu();
            }
            if (imgui.isItemClicked(.left)) {
                try editor.setOperation(.{ .Order = op });
            }
        }
        if (editor.Operation.Remove.init(editor.getIS())) |op| {
            if (imgui.menuItem("Remove", "DEL", false, true)) {
                try editor.setOperation(.{ .Remove = op });
            }
        }
        imgui.endPopup();
    }

    if (imgui.beginMainMenuBar()) {
        if (imgui.beginMenu("File", true)) {
            if (imgui.menuItem("Preferences", null, false, !preferences_open)) {
                preferences_open = true;
            }
            imgui.separator();
            if (imgui.menuItem("Exit", null, false, true)) {
                editor.should_run = false;
            }
            imgui.endMenu();
        }
        if (imgui.beginMenu("Edit", true)) {
            if (imgui.menuItem("Undo", "CTRL+Z", false, editor.history.canUndo())) {
                editor.undo();
            }
            if (imgui.menuItem("Redo", "CTRL+Y", false, editor.history.canRedo())) {
                editor.redo();
            }
            imgui.separator();
            if (imgui.menuItem("Select All", "CTRL+A", false, true)) {
                try editor.selectAll();
            }
            if (imgui.menuItem("Deselect All", null, false, true)) {
                editor.history.get().deselectAll();
                editor.should_draw_helper = true;
            }

            imgui.endMenu();
        }

        imgui.endMainMenuBar();
    }

    if (preferences_open) {
        imgui.setNextWindowSize(.{ .x = 512, .y = 512 }, .once);
        if (imgui.begin("Preferences", &preferences_open, .{})) {
            if (imgui.colorEdit4("canvas color", &editor.canvas_color, .{}))
                editor.should_draw_canvas = true;
            if (imgui.inputFloat2("canvas size", &editor.canvas_size[0], null, .{}))
                editor.should_draw_canvas = true;

            imgui.separator();

            _ = imgui.checkbox("operation live preview", &editor.live_preview);

            imgui.separator();

            if (imgui.colorEdit4("default fill color", &editor.default_style.fill_color, .{}))
                try editor.updateOperation();
            if (imgui.colorEdit4("default stroke color", &editor.default_style.stroke_color, .{}))
                try editor.updateOperation();
            if (imgui.inputFloat("default stroke width", &editor.default_style.stroke.width, 0, 0, null, .{}))
                try editor.updateOperation();
            if (imgui.beginCombo("default stroke cap", @tagName(editor.default_style.stroke.cap), .{})) {
                inline for (@typeInfo(math.Stroke.CapStyle).Enum.fields) |field| {
                    const tag = @field(math.Stroke.CapStyle, field.name);
                    if (imgui.selectable(field.name ++ "", editor.default_style.stroke.cap == tag, .{}, .{ .x = 0, .y = 0 })) {
                        editor.default_style.stroke.cap = tag;
                        try editor.updateOperation();
                    }
                }
                imgui.endCombo();
            }
        }
        imgui.end();
    }

    imgui.render();
}

pub fn isMouseCaptured() bool {
    return imgui.getIO().want_capture_mouse;
}

pub fn isKeyboardCaptured() bool {
    return imgui.getIO().want_capture_keyboard;
}

pub fn render(pass: *webgpu.RenderPassEncoder) void {
    imgui_impl_wgpu.renderDrawData(imgui.getDrawData().?, pass);
}

pub fn onEvent(event: platform.Event) void {
    if (editor.capture != null) return;
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
        .text_input => |text| io.addInputCharactersUTF8(text.ptr),
        .mouse_move => |pos| io.addMousePosEvent(@intToFloat(f32, pos[0]), @intToFloat(f32, pos[1])),
        .mouse_scroll => |offset| io.addMouseWheelEvent(0, @intToFloat(f32, offset)),
        .window_resize => |size| io.display_size = .{ .x = @intToFloat(f32, size[0]), .y = @intToFloat(f32, size[1]) },
        .window_focus, .window_unfocus => io.addFocusEvent(event == .window_focus),
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
