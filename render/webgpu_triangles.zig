const std = @import("std");
const platform = @import("platform");
const webgpu = @import("webgpu");

const webgpu_utils = @import("webgpu_utils.zig");
const geometry = @import("geometry.zig");
const linalg = @import("linalg.zig");

const step_angle = std.math.pi / 32.0;

const err = error.RendererError;

const vs_source =
    \\  struct VertexOut {
    \\      @builtin(position) position: vec4<f32>,
    \\      @location(0) color: vec4<f32>,
    \\  }
    \\  @vertex
    \\  fn main(@location(0) position: vec2<f32>, @location(1) color: vec4<f32>) -> VertexOut {
    \\      var out: VertexOut;
    \\      out.position = vec4<f32>(position, 0.0, 1.0);
    \\      out.color = color;
    \\      return out;
    \\  }
;

const fs_source =
    \\  @fragment
    \\  fn main(@location(0) color: vec4<f32>) -> @location(0) vec4<f32> {
    \\      return color;
    \\  }
;

const Vertex = struct {
    pos: [2]f32,
    color: [4]u8,
};

pub const Context = struct {
    instance: webgpu.Instance,
    surface: webgpu.Surface,
    adapter: webgpu.Adapter,
    device: webgpu.Device,
    swapchain: webgpu.SwapChain,
    pipeline: webgpu.RenderPipeline,

    pub fn init(window: platform.Window) !Context {
        const instance = webgpu.createInstance(&.{});
        const surface = webgpu_utils.createSurface(instance, window);
        const adapter = try webgpu_utils.createAdapter(instance, surface);
        const device = try webgpu_utils.createDevice(adapter);
        const swapchain = webgpu_utils.createSwapchain(device, surface, try window.getSize());

        const pipeline = device.createRenderPipeline(&.{
            .vertex = .{
                .module = device.createShaderModule(&.{
                    .next_in_chain = &webgpu.ShaderModuleWGSLDescriptor{ .source = vs_source },
                }),
                .entry_point = "main",
                .buffer_count = 1,
                .buffers = &[1]webgpu.VertexBufferLayout{.{
                    .array_stride = @sizeOf(Vertex),
                    .attribute_count = 2,
                    .attributes = &[2]webgpu.VertexAttribute{ .{
                        .format = .float32x2,
                        .offset = @offsetOf(Vertex, "pos"),
                        .shader_location = 0,
                    }, .{
                        .format = .unorm8x4,
                        .offset = @offsetOf(Vertex, "color"),
                        .shader_location = 1,
                    } },
                }},
            },
            .primitive = .{
                .topology = .triangle_list,
            },
            .fragment = &webgpu.FragmentState{
                .module = device.createShaderModule(&.{
                    .next_in_chain = &webgpu.ShaderModuleWGSLDescriptor{ .source = fs_source },
                }),
                .entry_point = "main",
                .target_count = 1,
                .targets = &[1]webgpu.ColorTargetState{.{
                    .format = .bgra8_unorm,
                }},
            },
        });

        return .{
            .instance = instance,
            .surface = surface,
            .adapter = adapter,
            .device = device,
            .swapchain = swapchain,
            .pipeline = pipeline,
        };
    }

    pub fn deinit(context: *Context) void {
        context.device.destroy();
    }

    pub fn onWindowResize(context: *Context, size: [2]u32) void {
        context.swapchain = webgpu_utils.createSwapchain(context.device, context.surface, size);
    }

    pub fn draw(context: Context, buffers: []const Buffer) void {
        const command_encoder = context.device.createCommandEncoder(&.{});
        const pass = command_encoder.beginRenderPass(&.{
            .color_attachment_count = 1,
            .color_attachments = &[1]webgpu.RenderPassColorAttachment{.{
                .view = context.swapchain.getCurrentTextureView(),
                .load_op = .clear,
                .store_op = .store,
                .clear_value = std.mem.zeroes(webgpu.Color),
            }},
        });
        pass.setPipeline(context.pipeline);
        for (buffers) |buffer| {
            pass.setVertexBuffer(0, buffer.vertex_buffer, 0, buffer.vertex_count * @sizeOf(Vertex));
            pass.setIndexBuffer(buffer.index_buffer, .uint32, 0, buffer.index_count * @sizeOf(u32));
            pass.drawIndexed(buffer.index_count, 1, 0, 0, 0);
        }
        pass.end();
        var command_buffer = command_encoder.finish(&.{});
        context.device.getQueue().submit(1, &[1]webgpu.CommandBuffer{command_buffer});
        context.swapchain.present();
    }
};

pub const Buffer = struct {
    context: Context,
    allocator: std.mem.Allocator,

    vertex_buffer: webgpu.Buffer,
    index_buffer: webgpu.Buffer,
    vertex_count: u32 = 0,
    index_count: u32 = 0,

    vertices: std.ArrayListUnmanaged(Vertex) = .{},
    indices: std.ArrayListUnmanaged(u32) = .{},

    pub fn init(context: Context, allocator: std.mem.Allocator) Buffer {
        return .{
            .context = context,
            .allocator = allocator,
            .vertex_buffer = context.device.createBuffer(&.{ .usage = .{ .vertex = true, .copy_dst = true }, .size = 0 }),
            .index_buffer = context.device.createBuffer(&.{ .usage = .{ .index = true, .copy_dst = true }, .size = 0 }),
        };
    }

    pub fn deinit(buffer: *Buffer) void {
        buffer.vertex_buffer.destroy();
        buffer.index_buffer.destroy();
        buffer.vertices.deinit(buffer.allocator);
        buffer.indices.deinit(buffer.allocator);
    }

    pub fn clearPaths(buffer: *Buffer) void {
        buffer.vertices.clearRetainingCapacity();
        buffer.indices.clearRetainingCapacity();
    }

    pub fn appendPath(buffer: *Buffer, path: geometry.Path, color: [4]u8) !void {
        std.debug.assert(path.isLooped());
        const first_index = @intCast(u32, buffer.vertices.items.len);

        var index: u32 = 0;
        while (index < path.len()) : (index += 1) {
            const step_count = @floatToInt(u32, @fabs(path.angleFrom(index).?) / step_angle) + 1;
            var step: u32 = 0;
            while (step < step_count) : (step += 1) {
                const pos = path.arcFrom(index).?.point(@intToFloat(f32, step) / @intToFloat(f32, step_count));
                try buffer.vertices.append(buffer.allocator, .{ .pos = pos, .color = color });
            }
        }
        // TODO: proper triangulation
        index = first_index;
        while (index + 2 < buffer.vertices.items.len) : (index += 1) {
            try buffer.indices.appendSlice(buffer.allocator, &.{ first_index, index + 1, index + 2 });
        }
    }

    pub fn flushPaths(buffer: *Buffer) void {
        const vertices_size = buffer.vertices.items.len * @sizeOf(Vertex);
        const indices_size = buffer.indices.items.len * @sizeOf(u32);

        if (vertices_size > buffer.vertex_buffer.getSize()) {
            buffer.vertex_buffer.destroy();
            buffer.vertex_buffer = buffer.context.device.createBuffer(&.{
                .usage = .{ .vertex = true, .copy_dst = true },
                .size = buffer.vertices.capacity * @sizeOf(Vertex),
            });
        }
        if (indices_size > buffer.index_buffer.getSize()) {
            buffer.index_buffer.destroy();
            buffer.index_buffer = buffer.context.device.createBuffer(&.{
                .usage = .{ .index = true, .copy_dst = true },
                .size = buffer.indices.capacity * @sizeOf(u32),
            });
        }

        buffer.context.device.getQueue().writeBuffer(buffer.vertex_buffer, 0, buffer.vertices.items.ptr, vertices_size);
        buffer.context.device.getQueue().writeBuffer(buffer.index_buffer, 0, buffer.indices.items.ptr, indices_size);

        buffer.vertex_count = @intCast(u32, buffer.vertices.items.len);
        buffer.index_count = @intCast(u32, buffer.indices.items.len);
    }
};
