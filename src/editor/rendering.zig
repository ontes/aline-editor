const std = @import("std");
const math = @import("math");
const platform = @import("platform");
const render = @import("render");
const webgpu = @import("webgpu");
const stb = @import("stb");

const gui = @import("gui.zig");

const texture_format = webgpu.TextureFormat.rgba8_unorm;

pub var context: render.Context = undefined;
pub var bind_group_layout: *webgpu.BindGroupLayout = undefined;
pub var screen_pipeline: *webgpu.RenderPipeline = undefined;
pub var texture_pipeline: *webgpu.RenderPipeline = undefined;

pub var canvas_buffer: render.fragments.Buffer = undefined;
pub var image_buffer: render.fragments.Buffer = undefined;
pub var helper_buffer: render.fragments.Buffer = undefined;

pub fn init(window: platform.Window, allocator: std.mem.Allocator) !void {
    context = try render.Context.init(window);
    bind_group_layout = render.fragments.createBindGroupLayout(context.device);
    screen_pipeline = render.fragments.createPipeline(context.device, bind_group_layout, render.Context.swapchain_format);
    texture_pipeline = render.fragments.createPipeline(context.device, bind_group_layout, texture_format);
    canvas_buffer = render.fragments.Buffer.init(context.device, bind_group_layout, allocator);
    image_buffer = render.fragments.Buffer.init(context.device, bind_group_layout, allocator);
    helper_buffer = render.fragments.Buffer.init(context.device, bind_group_layout, allocator);
}

pub fn deinit() void {
    canvas_buffer.deinit();
    image_buffer.deinit();
    helper_buffer.deinit();
    context.deinit();
}

pub fn setTransform(transform: math.Mat3) void {
    canvas_buffer.setTransform(transform);
    image_buffer.setTransform(transform);
    helper_buffer.setTransform(transform);
}

pub fn renderToScreen() void {
    const command_encoder = context.device.createCommandEncoder(&.{});
    const pass = render.beginRenderPass(command_encoder, context.swapchain.getCurrentTextureView(), .{ 0.8, 0.8, 0.8, 1 });

    pass.setPipeline(screen_pipeline);
    canvas_buffer.draw(pass);
    image_buffer.draw(pass);
    helper_buffer.draw(pass);
    gui.draw(pass);

    pass.end();
    render.submitCommands(context.device, command_encoder);
    context.swapchain.present();
}

pub fn renderToFile(path: [*:0]const u8, canvas_size: [2]u32, canvas_color: [4]f32) !void {
    const size = webgpu.Extent3D{ .width = canvas_size[0], .height = canvas_size[1] };
    setTransform(math.mat3.scale(.{ 2 / @intToFloat(f32, size.width), 2 / @intToFloat(f32, size.height), 1 }));

    const texture = context.device.createTexture(&.{
        .usage = .{ .render_attachment = true, .copy_src = true },
        .size = size,
        .format = texture_format,
    });
    defer texture.destroy();

    const buffer = context.device.createBuffer(&.{
        .usage = .{ .copy_dst = true, .map_read = true },
        .size = 4 * size.width * size.height,
    });
    defer buffer.destroy();

    const command_encoder = context.device.createCommandEncoder(&.{});
    const pass = render.beginRenderPass(command_encoder, texture.createView(&.{}), canvas_color);
    pass.setPipeline(texture_pipeline);
    image_buffer.draw(pass);
    pass.end();
    command_encoder.copyTextureToBuffer(&.{ .texture = texture }, &.{ .buffer = buffer, .layout = .{ .bytes_per_row = 4 * size.width } }, &size);
    render.submitCommands(context.device, command_encoder);

    const callback = struct {
        fn callback(status: webgpu.BufferMapAsyncStatus, userdata: ?*anyopaque) callconv(.C) void {
            @ptrCast(*webgpu.BufferMapAsyncStatus, @alignCast(@alignOf(webgpu.BufferMapAsyncStatus), userdata.?)).* = status;
        }
    }.callback;
    var status = webgpu.BufferMapAsyncStatus.unknown;
    buffer.mapAsync(.{ .read = true }, 0, webgpu.whole_size, &callback, &status);
    while (status == .unknown) {
        webgpu.dawn.wgpuDeviceTick(context.device);
    }
    if (status != .success)
        return error.WebgpuBufferMapError;
    const data = buffer.getConstMappedRange(0, webgpu.whole_size);

    if (stb.image.writePng(path, @intCast(c_int, size.width), @intCast(c_int, size.height), 4, data, @intCast(c_int, 4 * size.width)) == 0)
        return error.StbImageWriteError;
}
