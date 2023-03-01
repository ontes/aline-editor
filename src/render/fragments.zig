const std = @import("std");
const math = @import("math");
const platform = @import("platform");
const webgpu = @import("webgpu");

const err = error.WebgpuError;

const Context = @import("Context.zig");

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

pub fn createBindGroupLayout(device: *webgpu.Device) *webgpu.BindGroupLayout {
    return device.createBindGroupLayout(&.{
        .entry_count = 4,
        .entries = &[4]webgpu.BindGroupLayoutEntry{
            .{ .binding = 0, .visibility = .{ .vertex = true }, .buffer = .{ .binding_type = .uniform } },
            .{ .binding = 1, .visibility = .{ .vertex = true, .fragment = true }, .buffer = .{ .binding_type = .read_only_storage } },
            .{ .binding = 2, .visibility = .{ .fragment = true }, .buffer = .{ .binding_type = .read_only_storage } },
            .{ .binding = 3, .visibility = .{ .fragment = true }, .buffer = .{ .binding_type = .read_only_storage } },
        },
    });
}

pub fn createPipeline(device: *webgpu.Device, bind_group_layout: *webgpu.BindGroupLayout, output_format: webgpu.TextureFormat) *webgpu.RenderPipeline {
    return device.createRenderPipeline(&.{
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
                .format = output_format,
                .blend = &.{
                    .color = .{
                        .src_factor = .src_alpha,
                        .dst_factor = .one_minus_src_alpha,
                    },
                },
            }},
        },
    });
}

pub const Buffer = struct {
    device: *webgpu.Device,
    bind_group_layout: *webgpu.BindGroupLayout,
    allocator: std.mem.Allocator,

    transform_buffer: *webgpu.Buffer,
    entries_buffer: *webgpu.Buffer,
    positions_buffer: *webgpu.Buffer,
    angles_buffer: *webgpu.Buffer,
    bind_group: ?*webgpu.BindGroup = null,
    path_count: u32 = 0,

    entries: std.ArrayListUnmanaged(Entry) = .{},
    data: std.MultiArrayList(struct { position: @Vector(2, f32), angle: f32 }) = .{},

    pub fn init(device: *webgpu.Device, bind_group_layout: *webgpu.BindGroupLayout, allocator: std.mem.Allocator) Buffer {
        return .{
            .device = device,
            .bind_group_layout = bind_group_layout,
            .allocator = allocator,
            .transform_buffer = device.createBuffer(&.{ .usage = .{ .uniform = true, .copy_dst = true }, .size = @sizeOf(math.Mat3) }),
            .entries_buffer = device.createBuffer(&.{ .usage = .{ .storage = true, .copy_dst = true }, .size = 0 }),
            .positions_buffer = device.createBuffer(&.{ .usage = .{ .storage = true, .copy_dst = true }, .size = 0 }),
            .angles_buffer = device.createBuffer(&.{ .usage = .{ .storage = true, .copy_dst = true }, .size = 0 }),
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
        buffer.device.getQueue().writeBuffer(buffer.transform_buffer, 0, &transform, @sizeOf(math.Mat3));
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
            buffer.entries_buffer = buffer.device.createBuffer(&.{
                .usage = .{ .storage = true, .copy_dst = true },
                .size = entries_size,
            });
        }
        if (positions_size > buffer.positions_buffer.getSize()) {
            buffer.positions_buffer.destroy();
            buffer.positions_buffer = buffer.device.createBuffer(&.{
                .usage = .{ .storage = true, .copy_dst = true },
                .size = positions_size,
            });
        }
        if (angles_size > buffer.angles_buffer.getSize()) {
            buffer.angles_buffer.destroy();
            buffer.angles_buffer = buffer.device.createBuffer(&.{
                .usage = .{ .storage = true, .copy_dst = true },
                .size = angles_size,
            });
        }

        buffer.device.getQueue().writeBuffer(buffer.entries_buffer, 0, buffer.entries.items.ptr, entries_size);
        buffer.device.getQueue().writeBuffer(buffer.positions_buffer, 0, buffer.data.items(.position).ptr, positions_size);
        buffer.device.getQueue().writeBuffer(buffer.angles_buffer, 0, buffer.data.items(.angle).ptr, angles_size);

        buffer.path_count = @intCast(u32, buffer.entries.items.len);

        buffer.bind_group = if (entries_size > 0) buffer.device.createBindGroup(&.{
            .layout = buffer.bind_group_layout,
            .entry_count = 4,
            .entries = &[4]webgpu.BindGroupEntry{
                .{ .binding = 0, .buffer = buffer.transform_buffer, .offset = 0, .size = @sizeOf(math.Mat3) },
                .{ .binding = 1, .buffer = buffer.entries_buffer, .offset = 0, .size = entries_size },
                .{ .binding = 2, .buffer = buffer.positions_buffer, .offset = 0, .size = positions_size },
                .{ .binding = 3, .buffer = buffer.angles_buffer, .offset = 0, .size = angles_size },
            },
        }) else null;
    }

    pub fn draw(buffer: Buffer, pass: *webgpu.RenderPassEncoder) void {
        if (buffer.bind_group) |bind_group| {
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

        pub fn end(p: Pass) !void {
            const bounding_box = math.Arc.boundingBox(.{
                .pos_a = p.g.buffer.data.items(.position)[p.g.buffer.data.len - 1],
                .angle = p.g.buffer.data.items(.angle)[p.g.buffer.data.len - 1],
                .pos_b = p.g.buffer.data.items(.position)[p.g.buffer.lastEntry().offset],
            });
            p.g.buffer.lastEntry().min_pos = @min(p.g.buffer.lastEntry().min_pos, bounding_box[0]);
            p.g.buffer.lastEntry().max_pos = @max(p.g.buffer.lastEntry().max_pos, bounding_box[1]);
        }
    };
};
