const std = @import("std");
const platform = @import("../platform.zig");
const render = @import("../render.zig");
const webgpu = @import("../bindings/webgpu.zig");
const webgpu_utils = @import("webgpu_utils.zig");
const geometry = @import("../geometry.zig");
const mat3 = @import("../linalg.zig").mat(3, f32);

const err = error.RendererError;

const vs_source =
    \\  struct PathEntry {
    \\      offset: u32,
    \\      len: u32,
    \\      min_pos: vec2<f32>,
    \\      max_pos: vec2<f32>,
    \\      color: vec4<f32>,
    \\  }
    \\  struct VertexOut {
    \\      @builtin(position) screen_pos: vec4<f32>,
    \\      @location(0) pos: vec2<f32>,
    \\      @location(1) @interpolate(flat) instance_index: u32,
    \\  }
    \\  @group(0) @binding(0) var<uniform> transform: mat3x3<f32>;
    \\  @group(0) @binding(1) var<storage> paths: array<PathEntry>;
    \\  @vertex fn main(@builtin(vertex_index) vertex_index: u32, @builtin(instance_index) instance_index: u32) -> VertexOut {
    \\      let p = paths[instance_index];
    \\      let pos = array<vec2<f32>,4>(
    \\          p.min_pos,
    \\          vec2<f32>(p.min_pos.x, p.max_pos.y),
    \\          vec2<f32>(p.max_pos.x, p.min_pos.y),
    \\          p.max_pos
    \\      )[vertex_index];
    \\      let transformed_pos = transform * vec3<f32>(pos, 1);
    \\      return VertexOut(vec4<f32>(transformed_pos.xy, 0, transformed_pos.z), pos, instance_index);
    \\  }
;

const fs_source =
    \\  struct PathEntry {
    \\      offset: u32,
    \\      len: u32,
    \\      min_pos: vec2<f32>,
    \\      max_pos: vec2<f32>,
    \\      color: vec4<f32>,
    \\  }
    \\  @group(0) @binding(1) var<storage> paths: array<PathEntry>;
    \\  @group(0) @binding(2) var<storage> positions: array<vec2<f32>>;
    \\  @group(0) @binding(3) var<storage> angles: array<f32>;
    \\  @fragment fn main(@location(0) pos: vec2<f32>, @location(1) @interpolate(flat) instance_index: u32) -> @location(0) vec4<f32> {
    \\      let p = paths[instance_index];
    \\      var inside: bool = false;
    \\      for (var i: u32 = 0; i < p.len; i++) {
    \\          let angle = angles[p.offset + i];
    \\          let vec_a = positions[p.offset + i] - pos;
    \\          let vec_b = positions[p.offset + (i + 1) % p.len] - pos;
    \\          let pos_angle = atan2(-dot(vec_a, vec2<f32>(-vec_b.y, vec_b.x)), -dot(vec_a, vec_b));
    \\          let crossing_line = ((pos_angle > 0) == (vec_a.x > 0)) & ((pos_angle > 0) != (vec_b.x > 0));
    \\          let inside_arc = ((pos_angle > 0) == (angle > 0)) & (abs(pos_angle) < abs(angle));
    \\          inside = (inside != (crossing_line != inside_arc));
    \\      }
    \\      if (!inside) { discard; }
    \\      return p.color;
    \\  }
;

const PathEntry = extern struct {
    offset: u32,
    len: u32,
    min_pos: geometry.Vec2 align(8),
    max_pos: geometry.Vec2 align(8),
    color: [4]f32 align(16),
};

pub const Context = struct {
    instance: webgpu.Instance,
    surface: webgpu.Surface,
    adapter: webgpu.Adapter,
    device: webgpu.Device,
    swapchain: webgpu.SwapChain,
    bind_group_layout: webgpu.BindGroupLayout,
    pipeline: webgpu.RenderPipeline,

    pub fn init(window: platform.Window) !Context {
        const instance = webgpu.createInstance(&.{});
        const surface = webgpu_utils.createSurface(instance, window);
        const adapter = try webgpu_utils.createAdapter(instance, surface);
        const device = try webgpu_utils.createDevice(adapter);
        const swapchain = webgpu_utils.createSwapchain(device, surface, try window.getSize());

        const bind_group_layout = device.createBindGroupLayout(&.{
            .entry_count = 4,
            .entries = &[4]webgpu.BindGroupLayoutEntry{
                .{ .binding = 0, .visibility = .{ .vertex = true }, .buffer = .{ .binding_type = .uniform } },
                .{ .binding = 1, .visibility = .{ .vertex = true, .fragment = true }, .buffer = .{ .binding_type = .read_only_storage } },
                .{ .binding = 2, .visibility = .{ .fragment = true }, .buffer = .{ .binding_type = .read_only_storage } },
                .{ .binding = 3, .visibility = .{ .fragment = true }, .buffer = .{ .binding_type = .read_only_storage } },
            },
        });

        const pipeline = device.createRenderPipeline(&.{
            .layout = device.createPipelineLayout(&.{
                .bind_group_layout_count = 1,
                .bind_group_layouts = &[1]webgpu.BindGroupLayout{bind_group_layout},
            }),
            .vertex = .{
                .module = device.createShaderModule(&.{
                    .next_in_chain = &webgpu.ShaderModuleWGSLDescriptor{ .source = vs_source },
                }),
                .entry_point = "main",
                .buffer_count = 0,
                .buffers = &[0]webgpu.VertexBufferLayout{},
            },
            .primitive = .{
                .topology = .triangle_strip,
            },
            .fragment = &webgpu.FragmentState{
                .module = device.createShaderModule(&.{
                    .next_in_chain = &webgpu.ShaderModuleWGSLDescriptor{ .source = fs_source },
                }),
                .entry_point = "main",
                .target_count = 1,
                .targets = &[1]webgpu.ColorTargetState{.{
                    .format = .bgra8_unorm,
                    .blend = &.{
                        .color = .{
                            .src_factor = .src_alpha,
                            .dst_factor = .one_minus_src_alpha,
                        },
                    },
                }},
            },
        });

        return .{
            .instance = instance,
            .surface = surface,
            .adapter = adapter,
            .device = device,
            .swapchain = swapchain,
            .bind_group_layout = bind_group_layout,
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
            if (buffer.bind_group) |bind_group| {
                pass.setBindGroup(0, bind_group, 0, &[0]u32{});
                pass.draw(4, buffer.path_count, 0, 0);
            }
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

    transform_buffer: webgpu.Buffer,
    paths_buffer: webgpu.Buffer,
    positions_buffer: webgpu.Buffer,
    angles_buffer: webgpu.Buffer,
    bind_group: ?webgpu.BindGroup = null,
    path_count: u32 = 0,

    paths: std.ArrayListUnmanaged(PathEntry) = .{},
    positions: std.ArrayListUnmanaged(geometry.Vec2) = .{},
    angles: std.ArrayListUnmanaged(f32) = .{},

    pub fn init(context: Context, allocator: std.mem.Allocator) Buffer {
        return .{
            .context = context,
            .allocator = allocator,
            .transform_buffer = context.device.createBuffer(&.{ .usage = .{ .uniform = true, .copy_dst = true }, .size = @sizeOf(mat3.Matrix) }),
            .paths_buffer = context.device.createBuffer(&.{ .usage = .{ .storage = true, .copy_dst = true }, .size = 0 }),
            .positions_buffer = context.device.createBuffer(&.{ .usage = .{ .storage = true, .copy_dst = true }, .size = 0 }),
            .angles_buffer = context.device.createBuffer(&.{ .usage = .{ .storage = true, .copy_dst = true }, .size = 0 }),
        };
    }

    pub fn deinit(buffer: *Buffer) void {
        buffer.paths_buffer.destroy();
        buffer.positions_buffer.destroy();
        buffer.angles_buffer.destroy();
        buffer.paths.deinit(buffer.allocator);
        buffer.positions.deinit(buffer.allocator);
        buffer.angles.deinit(buffer.allocator);
    }

    pub fn clearPaths(buffer: *Buffer) void {
        buffer.paths.clearRetainingCapacity();
        buffer.positions.clearRetainingCapacity();
        buffer.angles.clearRetainingCapacity();
    }

    pub fn appendPath(buffer: *Buffer, path: geometry.Path, color: [4]u8) !void {
        std.debug.assert(path.isLooped());
        if (path.len() < 2) return;

        var min_pos = path.positions[0];
        var max_pos = path.positions[0];
        var i: u32 = 0;
        while (i < path.len()) : (i += 1) {
            const bounding_box = path.getArc(i).boundingBox();
            min_pos = @min(min_pos, bounding_box[0]);
            max_pos = @max(max_pos, bounding_box[1]);
        }

        try buffer.paths.append(buffer.allocator, .{
            .offset = @intCast(u32, buffer.positions.items.len),
            .len = @intCast(u32, path.len()),
            .min_pos = min_pos,
            .max_pos = max_pos,
            .color = colorToFloats(color),
        });
        try buffer.positions.appendSlice(buffer.allocator, path.positions);
        try buffer.angles.appendSlice(buffer.allocator, path.angles);
    }

    pub fn flushPaths(buffer: *Buffer) void {
        const paths_size = buffer.paths.items.len * @sizeOf(PathEntry);
        const positions_size = buffer.positions.items.len * @sizeOf(geometry.Vec2);
        const angles_size = buffer.angles.items.len * @sizeOf(f32);

        if (paths_size > buffer.paths_buffer.getSize()) {
            buffer.paths_buffer.destroy();
            buffer.paths_buffer = buffer.context.device.createBuffer(&.{
                .usage = .{ .storage = true, .copy_dst = true },
                .size = buffer.paths.capacity * @sizeOf(PathEntry),
            });
        }
        if (positions_size > buffer.positions_buffer.getSize()) {
            buffer.positions_buffer.destroy();
            buffer.positions_buffer = buffer.context.device.createBuffer(&.{
                .usage = .{ .storage = true, .copy_dst = true },
                .size = buffer.positions.capacity * @sizeOf(geometry.Vec2),
            });
        }
        if (angles_size > buffer.angles_buffer.getSize()) {
            buffer.angles_buffer.destroy();
            buffer.angles_buffer = buffer.context.device.createBuffer(&.{
                .usage = .{ .storage = true, .copy_dst = true },
                .size = buffer.angles.capacity * @sizeOf(f32),
            });
        }

        buffer.context.device.getQueue().writeBuffer(buffer.paths_buffer, 0, buffer.paths.items.ptr, paths_size);
        buffer.context.device.getQueue().writeBuffer(buffer.positions_buffer, 0, buffer.positions.items.ptr, positions_size);
        buffer.context.device.getQueue().writeBuffer(buffer.angles_buffer, 0, buffer.angles.items.ptr, angles_size);

        buffer.path_count = @intCast(u32, buffer.paths.items.len);

        buffer.bind_group = if (paths_size > 0) buffer.context.device.createBindGroup(&.{
            .layout = buffer.context.bind_group_layout,
            .entry_count = 4,
            .entries = &[4]webgpu.BindGroupEntry{
                .{ .binding = 0, .buffer = buffer.transform_buffer, .offset = 0, .size = @sizeOf(mat3.Matrix) },
                .{ .binding = 1, .buffer = buffer.paths_buffer, .offset = 0, .size = paths_size },
                .{ .binding = 2, .buffer = buffer.positions_buffer, .offset = 0, .size = positions_size },
                .{ .binding = 3, .buffer = buffer.angles_buffer, .offset = 0, .size = angles_size },
            },
        }) else null;
    }

    pub fn setTransform(buffer: *Buffer, transform: mat3.Matrix) void {
        buffer.context.device.getQueue().writeBuffer(buffer.transform_buffer, 0, &transform, @sizeOf(mat3.Matrix));
    }
};

fn colorToFloats(color: [4]u8) [4]f32 {
    return .{
        @intToFloat(f32, color[0]) / 255.0,
        @intToFloat(f32, color[1]) / 255.0,
        @intToFloat(f32, color[2]) / 255.0,
        @intToFloat(f32, color[3]) / 255.0,
    };
}
