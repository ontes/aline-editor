const std = @import("std");
const platform = @import("../platform.zig");
const render = @import("../render.zig");
const webgpu = @import("../bindings/webgpu.zig");

const err = error.RendererError;

pub const Context = struct {
    instance: webgpu.Instance,
    surface: webgpu.Surface,
    adapter: webgpu.Adapter,
    device: webgpu.Device,
    swapchain: webgpu.SwapChain,
    pipeline: webgpu.RenderPipeline,

    pub fn init(window: platform.Window) !Context {
        const instance = webgpu.createInstance(&.{});
        const surface = createSurface(instance, window);
        const adapter = try createAdapter(instance, surface);
        const device = try createDevice(adapter);
        const swapchain = createSwapchain(device, surface, try window.getSize());
        const pipeline = createPipeline(device);
        return .{ .instance = instance, .surface = surface, .adapter = adapter, .device = device, .swapchain = swapchain, .pipeline = pipeline };
    }

    pub fn deinit(context: *Context) void {
        context.device.destroy();
    }

    pub fn updateSize(context: *Context, size: [2]u32) void {
        context.swapchain = createSwapchain(context.device, context.surface, size);
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
            pass.setVertexBuffer(0, buffer.vertex_buffer, 0, buffer.vertex_count * @sizeOf(render.Vertex));
            pass.setIndexBuffer(buffer.index_buffer, .uint32, 0, buffer.index_count * @sizeOf(u32));
            pass.drawIndexed(@intCast(u32, buffer.index_count), 1, 0, 0, 0);
        }
        pass.end();
        var command_buffer = command_encoder.finish(&.{});
        context.device.getQueue().submit(1, &[1]webgpu.CommandBuffer{command_buffer});
        context.swapchain.present();
    }
};

pub const Buffer = struct {
    device: webgpu.Device,
    vertex_buffer: webgpu.Buffer,
    index_buffer: webgpu.Buffer,
    vertex_count: u32 = 0,
    index_count: u32 = 0,

    pub fn init(context: Context) Buffer {
        return .{
            .device = context.device,
            .vertex_buffer = context.device.createBuffer(&.{ .usage = .{ .vertex = true, .copy_dst = true }, .size = 0 }),
            .index_buffer = context.device.createBuffer(&.{ .usage = .{ .index = true, .copy_dst = true }, .size = 0 }),
        };
    }

    pub fn deinit(buffer: *Buffer) void {
        buffer.vertex_buffer.destroy();
        buffer.index_buffer.destroy();
    }

    pub inline fn write(buffer: *Buffer, vertices: []const render.Vertex, indices: []const u32) void {
        buffer.writeVertices(vertices);
        buffer.writeIndices(indices);
    }

    pub fn writeVertices(buffer: *Buffer, vertices: []const render.Vertex) void {
        if (vertices.len * @sizeOf(render.Vertex) > buffer.vertex_buffer.getSize()) {
            buffer.vertex_buffer.destroy();
            buffer.vertex_buffer = buffer.device.createBuffer(&.{
                .usage = .{ .vertex = true, .copy_dst = true },
                .size = @intCast(u32, vertices.len * @sizeOf(render.Vertex)),
            });
        }
        buffer.device.getQueue().writeBuffer(buffer.vertex_buffer, 0, vertices.ptr, @intCast(u32, vertices.len * @sizeOf(render.Vertex)));
        buffer.vertex_count = @intCast(u32, vertices.len);
    }

    pub fn writeIndices(buffer: *Buffer, indices: []const u32) void {
        if (indices.len * @sizeOf(u32) > buffer.index_buffer.getSize()) {
            buffer.index_buffer.destroy();
            buffer.index_buffer = buffer.device.createBuffer(&.{
                .usage = .{ .index = true, .copy_dst = true },
                .size = @intCast(u32, indices.len * @sizeOf(u32)),
            });
        }
        buffer.device.getQueue().writeBuffer(buffer.index_buffer, 0, indices.ptr, @intCast(u32, indices.len * @sizeOf(u32)));
        buffer.index_count = @intCast(u32, indices.len);
    }
};

const vs_source =
    \\  struct VertexOutput {
    \\      @builtin(position) position: vec4<f32>,
    \\      @location(0) color: vec4<f32>,
    \\  }
    \\  @vertex
    \\  fn main(@location(0) position: vec2<f32>, @location(1) color: vec4<f32>) -> VertexOutput {
    \\      var output: VertexOutput;
    \\      output.position = vec4<f32>(position, 0.0, 1.0);
    \\      output.color = color;
    \\      return output;
    \\  }
;

const fs_source =
    \\  @fragment
    \\  fn main(@location(0) color: vec4<f32>) -> @location(0) vec4<f32> {
    \\      return color;
    \\  }
;

pub fn createSurface(instance: webgpu.Instance, window: platform.Window) webgpu.Surface {
    return instance.createSurface(&.{
        .next_in_chain = switch (@import("builtin").target.os.tag) {
            .windows => &webgpu.SurfaceDescriptorFromWindowsHWND{
                .hinstance = platform.window_class.instance,
                .hwnd = window.win32,
            },
            .linux => &webgpu.SurfaceDescriptorFromXlibWindow{
                .display = platform.display,
                .window = @intCast(u32, @ptrToInt(window.x11)),
            },
            // .macos => blk: {
            //     const ns_window = glfw.Native(.{ .cocoa = true }).getCocoaWindow(window);
            //     const ns_view = objc.msgSend(ns_window, "contentView", .{}, *anyopaque); // [nsWindow contentView]

            //     // create a CAMetalLayer that covers the whole window that will be passed to CreateSurface
            //     objc.msgSend(ns_view, "setWantsLayer:", .{true}, void); // [view setWantsLayer:YES]
            //     const layer = objc.msgSend(objc.getClass("CAMetalLayer"), "layer", .{}, ?*anyopaque) orelse return err; // [CAMetalLayer layer]
            //     objc.msgSend(ns_view, "setLayer:", .{layer}, void); // [view setLayer:layer]

            //     // use retina if the window was created with retina support
            //     const scale_factor = objc.msgSend(ns_window, "backingScaleFactor", .{}, f64); // [ns_window backingScaleFactor]
            //     objc.msgSend(layer, "setContentsScale:", .{scale_factor}, void); // [layer setContentsScale:scale_factor]

            //     break :blk .{ .metal = .{ .layer = layer } };
            // },
            else => @compileError("unsupported os"),
        },
    });
}

fn createAdapter(instance: webgpu.Instance, surface: webgpu.Surface) !webgpu.Adapter {
    const Response = struct {
        status: webgpu.RequestAdapterStatus = .unknown,
        adapter: ?webgpu.Adapter = null,
    };
    const callback = struct {
        fn callback(status: webgpu.RequestAdapterStatus, adapter: ?webgpu.Adapter, message: [*:0]const u8, userdata: ?*anyopaque) callconv(.C) void {
            if (status == .error_) @panic(std.mem.span(message));
            @ptrCast(*Response, @alignCast(@alignOf(*Response), userdata.?)).* = .{ .status = status, .adapter = adapter };
        }
    }.callback;

    var response = Response{};
    instance.requestAdapter(&.{ .compatible_surface = surface }, &callback, &response);
    if (response.status != .success or response.adapter == null) return err;

    var properties = std.mem.zeroes(webgpu.AdapterProperties);
    response.adapter.?.getProperties(&properties);
    std.debug.print("Running {s} backend on {s} (driver {s}).\n", .{
        @tagName(properties.backend_type),
        properties.name,
        properties.driver_description,
    });

    return response.adapter.?;
}

fn createDevice(adapter: webgpu.Adapter) !webgpu.Device {
    const Response = struct {
        status: webgpu.RequestDeviceStatus = .unknown,
        device: ?webgpu.Device = null,
    };
    const callback = struct {
        fn callback(status: webgpu.RequestDeviceStatus, device: ?webgpu.Device, message: [*:0]const u8, userdata: ?*anyopaque) callconv(.C) void {
            if (status == .error_) @panic(std.mem.span(message));
            @ptrCast(*Response, @alignCast(@alignOf(*Response), userdata.?)).* = .{ .status = status, .device = device };
        }
    }.callback;

    var response = Response{};
    adapter.requestDevice(&.{}, &callback, &response);
    if (response.status != .success or response.device == null) return err;

    return response.device.?;
}

fn createSwapchain(device: webgpu.Device, surface: webgpu.Surface, size: [2]u32) webgpu.SwapChain {
    return device.createSwapChain(surface, &.{
        .usage = .{ .render_attachment = true },
        .format = .bgra8_unorm,
        .width = size[0],
        .height = size[1],
        .present_mode = .fifo,
    });
}

fn createPipeline(device: webgpu.Device) webgpu.RenderPipeline {
    return device.createRenderPipeline(&.{
        .vertex = .{
            .module = device.createShaderModule(&.{
                .next_in_chain = &webgpu.ShaderModuleWGSLDescriptor{ .source = vs_source },
            }),
            .entry_point = "main",
            .buffer_count = 1,
            .buffers = &[1]webgpu.VertexBufferLayout{.{
                .array_stride = @sizeOf(render.Vertex),
                .attribute_count = 2,
                .attributes = &[2]webgpu.VertexAttribute{ .{
                    .format = .float32x2,
                    .offset = @offsetOf(render.Vertex, "pos"),
                    .shader_location = 0,
                }, .{
                    .format = .unorm8x4,
                    .offset = @offsetOf(render.Vertex, "color"),
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
}
