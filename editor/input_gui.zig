const std = @import("std");
const platform = @import("platform");
const render = @import("render");
const imgui = @import("imgui");
const imgui_impl_wgpu = @import("imgui_impl_wgpu");

const editor = @import("editor.zig");
const grabs = @import("grabs.zig");

pub fn init(context: render.Context) void {
    _ = imgui.createContext(null);
    platform.imgui_impl.init();
    _ = imgui_impl_wgpu.init(context.device, 3, .bgra8_unorm, .undef);
    imgui.styleColorsLight(null);
}

pub fn deinit() void {
    platform.imgui_impl.shutdown();
    imgui_impl_wgpu.shutdown();
    imgui.destroyContext(null);
}

pub fn onFrame() !void {
    platform.imgui_impl.newFrame();
    imgui_impl_wgpu.newFrame();
    imgui.newFrame();

    if (editor.operation) |*any_operation| {
        imgui.setNextWindowSize(.{ .x = 256, .y = 256 }, .none);
        _ = imgui.begin("Operation", null, .{});
        switch (any_operation.*) {
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
        }
        imgui.end();
    }

    imgui.render();
}

pub fn onEvent(event: platform.Event) void {
    platform.imgui_impl.handleEvent(event);
}

pub fn isGrabbed() bool {
    const io = imgui.getIO();
    return io.want_capture_mouse or io.want_capture_keyboard;
}
