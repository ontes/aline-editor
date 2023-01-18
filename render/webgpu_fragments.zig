const std = @import("std");
const math = @import("math");
const platform = @import("platform");
const webgpu = @import("webgpu");

const webgpu_utils = @import("webgpu_utils.zig");

const err = error.RendererError;

const vs_source =
    \\  struct Entry {
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
    \\  @group(0) @binding(1) var<storage> entries: array<Entry>;
    \\  @vertex fn main(@builtin(vertex_index) vertex_index: u32, @builtin(instance_index) instance_index: u32) -> VertexOut {
    \\      let e = entries[instance_index];
    \\      let pos = array<vec2<f32>,4>(
    \\          e.min_pos,
    \\          vec2<f32>(e.min_pos.x, e.max_pos.y),
    \\          vec2<f32>(e.max_pos.x, e.min_pos.y),
    \\          e.max_pos
    \\      )[vertex_index];
    \\      let transformed_pos = transform * vec3<f32>(pos, 1);
    \\      return VertexOut(vec4<f32>(transformed_pos.xy, 0, transformed_pos.z), pos, instance_index);
    \\  }
;

const fs_source =
    \\  struct Entry {
    \\      offset: u32,
    \\      len: u32,
    \\      min_pos: vec2<f32>,
    \\      max_pos: vec2<f32>,
    \\      color: vec4<f32>,
    \\  }
    \\  @group(0) @binding(1) var<storage> entries: array<Entry>;
    \\  @group(0) @binding(2) var<storage> positions: array<vec2<f32>>;
    \\  @group(0) @binding(3) var<storage> angles: array<f32>;
    \\  @fragment fn main(@location(0) pos: vec2<f32>, @location(1) @interpolate(flat) instance_index: u32) -> @location(0) vec4<f32> {
    \\      let e = entries[instance_index];
    \\      var inside: bool = false;
    \\      for (var i: u32 = 0; i < e.len; i++) {
    \\          let angle = angles[e.offset + i];
    \\          let vec_a = positions[e.offset + i] - pos;
    \\          let vec_b = positions[e.offset + (i + 1) % e.len] - pos;
    \\          let pos_angle = atan2(-dot(vec_a, vec2<f32>(-vec_b.y, vec_b.x)), -dot(vec_a, vec_b));
    \\          let crossing_line = ((pos_angle > 0) == (vec_a.x > 0)) & ((pos_angle > 0) != (vec_b.x > 0));
    \\          let inside_arc = ((pos_angle > 0) == (angle > 0)) & (abs(pos_angle) < abs(angle));
    \\          inside = (inside != (crossing_line != inside_arc));
    \\      }
    \\      if (!inside) { discard; }
    \\      return e.color;
    \\  }
;

const Entry = extern struct {
    offset: u32,
    len: u32,
    min_pos: @Vector(2, f32) align(8),
    max_pos: @Vector(2, f32) align(8),
    color: [4]f32 align(16),
};

pub const Context = struct {
    instance: *webgpu.Instance,
    surface: *webgpu.Surface,
    adapter: *webgpu.Adapter,
    device: *webgpu.Device,
    swapchain: *webgpu.SwapChain,
    bind_group_layout: *webgpu.BindGroupLayout,
    pipeline: *webgpu.RenderPipeline,

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
                .bind_group_layouts = &[1]*webgpu.BindGroupLayout{bind_group_layout},
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

    pub fn render(context: Context, comptime draw_fn: fn (pass: *webgpu.RenderPassEncoder) void) void {
        const command_encoder = context.device.createCommandEncoder(&.{});
        const pass = command_encoder.beginRenderPass(&.{
            .color_attachment_count = 1,
            .color_attachments = &[1]webgpu.RenderPassColorAttachment{.{
                .view = context.swapchain.getCurrentTextureView(),
                .load_op = .clear,
                .store_op = .store,
                .clear_value = .{ .r = 0.9, .g = 0.9, .b = 0.9, .a = 1 },
            }},
        });
        draw_fn(pass);
        pass.end();
        var command_buffer = command_encoder.finish(&.{});
        context.device.getQueue().submit(1, &[1]*webgpu.CommandBuffer{command_buffer});
        context.swapchain.present();
    }
};

pub const Buffer = struct {
    context: *const Context,
    allocator: std.mem.Allocator,

    transform_buffer: *webgpu.Buffer,
    entries_buffer: *webgpu.Buffer,
    positions_buffer: *webgpu.Buffer,
    angles_buffer: *webgpu.Buffer,
    bind_group: ?*webgpu.BindGroup = null,
    path_count: u32 = 0,

    entries: std.ArrayListUnmanaged(Entry) = .{},
    data: std.MultiArrayList(struct { position: @Vector(2, f32), angle: f32 }) = .{},

    pub fn init(context: *const Context, allocator: std.mem.Allocator) Buffer {
        return .{
            .context = context,
            .allocator = allocator,
            .transform_buffer = context.device.createBuffer(&.{ .usage = .{ .uniform = true, .copy_dst = true }, .size = @sizeOf(math.Mat3) }),
            .entries_buffer = context.device.createBuffer(&.{ .usage = .{ .storage = true, .copy_dst = true }, .size = 0 }),
            .positions_buffer = context.device.createBuffer(&.{ .usage = .{ .storage = true, .copy_dst = true }, .size = 0 }),
            .angles_buffer = context.device.createBuffer(&.{ .usage = .{ .storage = true, .copy_dst = true }, .size = 0 }),
        };
    }

    pub fn deinit(buffer: *Buffer) void {
        buffer.entries_buffer.destroy();
        buffer.positions_buffer.destroy();
        buffer.angles_buffer.destroy();
        buffer.entries.deinit(buffer.allocator);
        buffer.data.deinit(buffer.allocator);
    }

    pub fn setTransform(buffer: *Buffer, transform: math.Mat3) void {
        buffer.context.device.getQueue().writeBuffer(buffer.transform_buffer, 0, &transform, @sizeOf(math.Mat3));
    }

    pub fn clear(buffer: *Buffer) void {
        buffer.entries.clearRetainingCapacity();
        buffer.data.shrinkRetainingCapacity(0);
    }

    pub fn flush(buffer: *Buffer) void {
        const entries_size = buffer.entries.items.len * @sizeOf(Entry);
        const positions_size = buffer.data.len * @sizeOf(@Vector(2, f32));
        const angles_size = buffer.data.len * @sizeOf(f32);

        if (entries_size > buffer.entries_buffer.getSize()) {
            buffer.entries_buffer.destroy();
            buffer.entries_buffer = buffer.context.device.createBuffer(&.{
                .usage = .{ .storage = true, .copy_dst = true },
                .size = entries_size,
            });
        }
        if (positions_size > buffer.positions_buffer.getSize()) {
            buffer.positions_buffer.destroy();
            buffer.positions_buffer = buffer.context.device.createBuffer(&.{
                .usage = .{ .storage = true, .copy_dst = true },
                .size = positions_size,
            });
        }
        if (angles_size > buffer.angles_buffer.getSize()) {
            buffer.angles_buffer.destroy();
            buffer.angles_buffer = buffer.context.device.createBuffer(&.{
                .usage = .{ .storage = true, .copy_dst = true },
                .size = angles_size,
            });
        }

        buffer.context.device.getQueue().writeBuffer(buffer.entries_buffer, 0, buffer.entries.items.ptr, entries_size);
        buffer.context.device.getQueue().writeBuffer(buffer.positions_buffer, 0, buffer.data.items(.position).ptr, positions_size);
        buffer.context.device.getQueue().writeBuffer(buffer.angles_buffer, 0, buffer.data.items(.angle).ptr, angles_size);

        buffer.path_count = @intCast(u32, buffer.entries.items.len);

        buffer.bind_group = if (entries_size > 0) buffer.context.device.createBindGroup(&.{
            .layout = buffer.context.bind_group_layout,
            .entry_count = 4,
            .entries = &[4]webgpu.BindGroupEntry{
                .{ .binding = 0, .buffer = buffer.transform_buffer, .offset = 0, .size = @sizeOf(math.Mat3) },
                .{ .binding = 1, .buffer = buffer.entries_buffer, .offset = 0, .size = entries_size },
                .{ .binding = 2, .buffer = buffer.positions_buffer, .offset = 0, .size = positions_size },
                .{ .binding = 3, .buffer = buffer.angles_buffer, .offset = 0, .size = angles_size },
            },
        }) else null;
    }

    pub fn render(buffer: Buffer, pass: *webgpu.RenderPassEncoder) void {
        if (buffer.bind_group) |bind_group| {
            pass.setPipeline(buffer.context.pipeline);
            pass.setBindGroup(0, bind_group, 0, &[0]u32{});
            pass.draw(4, buffer.path_count, 0, 0);
        }
    }

    pub fn generator(buffer: *Buffer, color: [4]f32) Generator {
        return .{ .buffer = buffer, .color = color };
    }

    inline fn lastEntry(buffer: *Buffer) *Entry {
        return &buffer.entries.items[buffer.entries.items.len - 1];
    }
};

pub const Generator = struct {
    buffer: *Buffer,
    color: [4]f32,

    pub fn begin(g: Generator) Pass {
        return .{ .g = g };
    }

    pub const Pass = struct {
        g: Generator,
        is_first: bool = true,

        pub fn add(p: *Pass, pos: @Vector(2, f32), angle: f32) !void {
            if (p.is_first) {
                try p.g.buffer.entries.append(p.g.buffer.allocator, .{
                    .offset = @intCast(u32, p.g.buffer.data.len),
                    .len = 0,
                    .min_pos = pos,
                    .max_pos = pos,
                    .color = p.g.color,
                });
                p.is_first = false;
            } else {
                const bounding_box = math.Arc.boundingBox(.{
                    .pos_a = p.g.buffer.data.items(.position)[p.g.buffer.data.len - 1],
                    .angle = p.g.buffer.data.items(.angle)[p.g.buffer.data.len - 1],
                    .pos_b = pos,
                });
                p.g.buffer.lastEntry().min_pos = @min(p.g.buffer.lastEntry().min_pos, bounding_box[0]);
                p.g.buffer.lastEntry().max_pos = @max(p.g.buffer.lastEntry().max_pos, bounding_box[1]);
            }
            try p.g.buffer.data.append(p.g.buffer.allocator, .{ .position = pos, .angle = angle });
            p.g.buffer.lastEntry().len += 1;
        }

        pub fn end(p: *Pass, pos: @Vector(2, f32), angle: ?f32) !void {
            std.debug.assert(!p.is_first); // we can't render just one point
            try p.add(pos, angle.?);
            const bounding_box = math.Arc.boundingBox(.{
                .pos_a = p.g.buffer.data.items(.position)[p.g.buffer.data.len - 1],
                .angle = p.g.buffer.data.items(.angle)[p.g.buffer.data.len - 1],
                .pos_b = p.g.buffer.data.items(.position)[p.g.buffer.lastEntry().offset],
            });
            p.g.buffer.lastEntry().min_pos = @min(p.g.buffer.lastEntry().min_pos, bounding_box[0]);
            p.g.buffer.lastEntry().max_pos = @max(p.g.buffer.lastEntry().max_pos, bounding_box[1]);
            p.* = undefined;
        }
    };
};
