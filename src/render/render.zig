const webgpu = @import("webgpu");

pub const Context = @import("Context.zig");
pub const fragments = @import("fragments.zig");

fn render(device: *webgpu.Device, texture_view: *webgpu.TextureView, clear_color: [4]f32, comptime draw_fn: fn (pass: *webgpu.RenderPassEncoder) void) void {
    const command_encoder = device.createCommandEncoder(&.{});
    const pass = command_encoder.beginRenderPass(&.{
        .color_attachment_count = 1,
        .color_attachments = &[1]webgpu.RenderPassColorAttachment{.{
            .view = texture_view,
            .load_op = .clear,
            .store_op = .store,
            .clear_value = .{ .r = clear_color[0], .g = clear_color[1], .b = clear_color[2], .a = clear_color[3] },
        }},
    });
    draw_fn(pass);
    pass.end();
    var command_buffer = command_encoder.finish(&.{});
    device.getQueue().submit(1, &[1]*webgpu.CommandBuffer{command_buffer});
}

pub fn renderToScreen(context: Context, clear_color: [4]f32, comptime draw_fn: fn (pass: *webgpu.RenderPassEncoder) void) void {
    render(context.device, context.swapchain.getCurrentTextureView(), clear_color, draw_fn);
    context.swapchain.present();
}
