const std = @import("std");
const platform = @import("../platform.zig");
const render = @import("../render.zig");
const webgpu = @import("../bindings/webgpu.zig");
const webgpu_utils = @import("webgpu_utils.zig");
const geometry = @import("../geometry.zig");
const vec2 = @import("../linalg.zig").vec(2, f32);

const err = error.RendererError;

const vs_source =
    \\  struct PathEntry {
    \\      offset: u32,
    \\      len: u32,
    \\      min_pos: vec2<f32>,
    \\      max_pos: vec2<f32>,
    \\      color: vec4<f32>,
    \\  }
    \\  @group(0) @binding(0) var<storage> paths: array<PathEntry>;
    \\  struct VertexOut {
    \\      @builtin(position) screen_pos: vec4<f32>,
    \\      @location(0) pos: vec2<f32>,
    \\      @location(1) @interpolate(flat) instance_index: u32,
    \\  }
    \\  @vertex
    \\  fn main(@builtin(vertex_index) vertex_index: u32, @builtin(instance_index) instance_index: u32) -> VertexOut {
    \\      let p = paths[instance_index];
    \\      let positions = array<vec2<f32>,4>(
    \\          p.min_pos,
    \\          vec2<f32>(p.min_pos.x, p.max_pos.y),
    \\          vec2<f32>(p.max_pos.x, p.min_pos.y),
    \\          p.max_pos
    \\      );
    \\      var out: VertexOut;
    \\      out.pos = positions[vertex_index];
    \\      out.screen_pos = vec4<f32>(out.pos, 0, 1);
    \\      out.instance_index = instance_index;
    \\      return out;
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
    \\  @group(0) @binding(0) var<storage> paths: array<PathEntry>;
    \\  @group(0) @binding(1) var<storage> positions: array<vec2<f32>>;
    \\  @group(0) @binding(2) var<storage> angles: array<f32>;
    \\  @fragment
    \\  fn main(@location(0) pos: vec2<f32>, @location(1) @interpolate(flat) instance_index: u32) -> @location(0) vec4<f32> {
    \\      let p = paths[instance_index];
    \\      var inside: bool = false;
    \\      for (var i: u32 = 0; i < p.len; i++) {
    \\          let j = (i + 1) % p.len;
    \\          inside = (inside != isCrossingLine(pos, positions[p.offset + i], positions[p.offset + j]));
    \\          inside = (inside != isInArc(pos, positions[p.offset + i], positions[p.offset + j], angles[p.offset + i]));
    \\      }
    \\      if (!inside) { discard; }
    \\      return p.color;
    \\  }
    \\  fn isCrossingLine(pos: vec2<f32>, pos_a: vec2<f32>, pos_b: vec2<f32>) -> bool {
    \\      return ((pos.y < pos_a.y) != (pos.y < pos_b.y)) &
    \\          (pos.x < (pos_b.x - pos_a.x) / (pos_b.y - pos_a.y) * (pos.y - pos_a.y) + pos_a.x);
    \\  }
    \\  fn arcAngle(pos: vec2<f32>, pos_a: vec2<f32>, pos_b: vec2<f32>) -> f32 {
    \\      let vec_a = pos_a - pos;
    \\      let vec_b = pos - pos_b;
    \\      return -atan2(vec_a.x * vec_b.y - vec_a.y * vec_b.x, vec_a.x * vec_b.x + vec_a.y * vec_b.y);
    \\  }
    \\  fn isInArc(pos: vec2<f32>, pos_a: vec2<f32>, pos_b: vec2<f32>, angle: f32) -> bool {
    \\      let pos_angle = arcAngle(pos, pos_a, pos_b);
    \\      return (sign(pos_angle) == sign(angle)) & (abs(pos_angle) < abs(angle));
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
            .entry_count = 3,
            .entries = &[3]webgpu.BindGroupLayoutEntry{
                .{ .binding = 0, .visibility = .{ .vertex = true, .fragment = true }, .buffer = .{ .binding_type = .read_only_storage } },
                .{ .binding = 1, .visibility = .{ .fragment = true }, .buffer = .{ .binding_type = .read_only_storage } },
                .{ .binding = 2, .visibility = .{ .fragment = true }, .buffer = .{ .binding_type = .read_only_storage } },
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

    pub fn updateSize(context: *Context, size: [2]u32) void {
        context.swapchain = webgpu_utils.createSwapchain(context.device, context.surface, size);
    }

    pub fn update(context: Context, buffers: []const Buffer) void {
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

    pub fn clear(buffer: *Buffer) void {
        buffer.paths.clearRetainingCapacity();
        buffer.positions.clearRetainingCapacity();
        buffer.angles.clearRetainingCapacity();
    }

    pub fn append(buffer: *Buffer, path: geometry.Path, color: [4]u8) !void {
        std.debug.assert(path.isLooped());
        if (path.len() == 0) return;

        var min_pos = path.positions[0];
        var max_pos = path.positions[0];
        var index: u32 = 0;
        while (index < path.len()) : (index += 1) {
            const bounding_box = path.arcFrom(index).?.boundingBox();
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

    pub fn flush(buffer: *Buffer) void {
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
            .entry_count = 3,
            .entries = &[3]webgpu.BindGroupEntry{
                .{ .binding = 0, .buffer = buffer.paths_buffer, .offset = 0, .size = paths_size },
                .{ .binding = 1, .buffer = buffer.positions_buffer, .offset = 0, .size = positions_size },
                .{ .binding = 2, .buffer = buffer.angles_buffer, .offset = 0, .size = angles_size },
            },
        }) else null;
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
