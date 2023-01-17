const std = @import("std");
const platform = @import("platform");
const render = @import("render");
const imgui = @import("imgui");
const imgui_impl_wgpu = @import("imgui_impl_wgpu");

const operations = @import("operations.zig");

pub fn init(context: render.Context) void {
    _ = imgui.createContext(null);
    platform.imgui_impl.init();
    _ = imgui_impl_wgpu.init(context.device, 3, .bgra8_unorm, .undef);

    imgui.styleColorsLight(null);

    std.debug.print("Font atlas: {}\n", .{@ptrToInt(imgui.getIO().fonts)});
}

pub fn deinit() void {
    platform.imgui_impl.shutdown();
    imgui_impl_wgpu.shutdown();
    imgui.destroyContext(null);
}

pub fn update(pending_operation: *?operations.AnyOperation) void {
    platform.imgui_impl.newFrame();
    imgui_impl_wgpu.newFrame();
    imgui.newFrame();

    if (pending_operation.*) |*any_operation| {
        imgui.setNextWindowSize(.{ .x = 200, .y = 200 }, .none);
        switch (any_operation.*) {
            .AddPoint => |*operation| {
                _ = imgui.begin("Add Point", null, .{});
                _ = imgui.inputFloat2("position", &operation.position.val[0], null, .{});
                imgui.end();
            },
            .Append => {
                _ = imgui.begin("Append", null, .{});
                imgui.end();
            },
            .Connect => {
                _ = imgui.begin("Connect", null, .{});
                imgui.end();
            },
            .Move => {
                _ = imgui.begin("Move", null, .{});
                imgui.end();
            },
            .Remove => {
                _ = imgui.begin("Remove", null, .{});
                imgui.end();
            },
            .ChangeAngle => {
                _ = imgui.begin("Change Angle", null, .{});
                imgui.end();
            },
        }
    }

    imgui.render();
}

pub fn handleEvent(event: platform.Event) void {
    platform.imgui_impl.handleEvent(event);
}

pub fn isMouseCaptured() bool {
    return imgui.getIO().want_capture_mouse;
}
