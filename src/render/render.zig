const webgpu = @import("webgpu");

pub const Context = @import("Context.zig");
pub const fragments = @import("fragments.zig");

pub fn beginRenderPass(command_encoder: *webgpu.CommandEncoder, texture_view: *webgpu.TextureView, clear_color: [4]f32) *webgpu.RenderPassEncoder {
    return command_encoder.beginRenderPass(&.{
        .color_attachment_count = 1,
        .color_attachments = &[1]webgpu.RenderPassColorAttachment{.{
            .view = texture_view,
            .load_op = .clear,
            .store_op = .store,
            .clear_value = .{ .r = clear_color[0], .g = clear_color[1], .b = clear_color[2], .a = clear_color[3] },
        }},
    });
}

pub fn submitCommands(device: *webgpu.Device, command_encoder: *webgpu.CommandEncoder) void {
    var command_buffer = command_encoder.finish(&.{});
    device.getQueue().submit(1, &[1]*webgpu.CommandBuffer{command_buffer});
}
