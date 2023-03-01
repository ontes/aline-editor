const std = @import("std");
const webgpu = @import("webgpu");
const platform = @import("platform");

const err = error.WebgpuError;

const Context = @This();

instance: *webgpu.Instance,
surface: *webgpu.Surface,
adapter: *webgpu.Adapter,
device: *webgpu.Device,
swapchain: *webgpu.SwapChain,

pub const swapchain_format: webgpu.TextureFormat = .bgra8_unorm;

pub fn init(window: platform.Window) !Context {
    const instance = webgpu.createInstance(&.{});

    const surface = instance.createSurface(&.{
        .next_in_chain = switch (@import("builtin").target.os.tag) {
            .windows => &webgpu.SurfaceDescriptorFromWindowsHWND{
                .hinstance = platform.window_class.instance,
                .hwnd = window.win32,
            },
            .linux => &webgpu.SurfaceDescriptorFromXlibWindow{
                .display = platform.display,
                .window = @intCast(u32, window.x11),
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

    const adapter = adapter: {
        const Response = struct {
            status: webgpu.RequestAdapterStatus = .unknown,
            adapter: ?*webgpu.Adapter = undefined,
        };
        const callback = struct {
            fn callback(status: webgpu.RequestAdapterStatus, adapter: ?*webgpu.Adapter, message: [*:0]const u8, userdata: ?*anyopaque) callconv(.C) void {
                if (status == .error_) @panic(std.mem.span(message));
                @ptrCast(*Response, @alignCast(@alignOf(*Response), userdata.?)).* = .{ .status = status, .adapter = adapter };
            }
        }.callback;

        var response = Response{};
        instance.requestAdapter(&.{ .compatible_surface = surface }, &callback, &response);
        if (response.status != .success) return err;

        var properties = std.mem.zeroes(webgpu.AdapterProperties);
        response.adapter.?.getProperties(&properties);
        std.debug.print("Running {s} backend on {s} (driver {s}).\n", .{
            @tagName(properties.backend_type),
            properties.name,
            properties.driver_description,
        });
        break :adapter response.adapter.?;
    };

    const device = device: {
        const Response = struct {
            status: webgpu.RequestDeviceStatus = .unknown,
            device: ?*webgpu.Device = undefined,
        };
        const callback = struct {
            fn callback(status: webgpu.RequestDeviceStatus, device: ?*webgpu.Device, message: [*:0]const u8, userdata: ?*anyopaque) callconv(.C) void {
                if (status == .error_) @panic(std.mem.span(message));
                @ptrCast(*Response, @alignCast(@alignOf(*Response), userdata.?)).* = .{ .status = status, .device = device };
            }
        }.callback;

        var response = Response{};
        adapter.requestDevice(&.{}, &callback, &response);
        if (response.status != .success) return err;

        const errorCallback = struct {
            fn errorCallback(error_type: webgpu.ErrorType, message: [*:0]const u8, _: ?*anyopaque) callconv(.C) void {
                _ = error_type;
                @panic(std.mem.span(message));
            }
        }.errorCallback;
        response.device.?.setUncapturedErrorCallback(&errorCallback, null);

        const lostCallback = struct {
            fn lostCallback(reason: webgpu.DeviceLostReason, message: [*:0]const u8, _: ?*anyopaque) callconv(.C) void {
                _ = reason;
                std.debug.print("{s}\n", .{message});
            }
        }.lostCallback;
        response.device.?.setDeviceLostCallback(&lostCallback, null);

        break :device response.device.?;
    };

    return .{
        .instance = instance,
        .surface = surface,
        .adapter = adapter,
        .device = device,
        .swapchain = createSwapchain(device, surface, try window.getSize()),
    };
}

pub fn deinit(context: *Context) void {
    context.device.destroy();
}

pub fn onWindowResize(context: *Context, size: [2]u32) void {
    context.swapchain = createSwapchain(context.device, context.surface, size);
}

fn createSwapchain(device: *webgpu.Device, surface: *webgpu.Surface, size: [2]u32) *webgpu.SwapChain {
    return device.createSwapChain(surface, &.{
        .usage = .{ .render_attachment = true },
        .format = swapchain_format,
        .width = size[0],
        .height = size[1],
        .present_mode = .fifo,
    });
}
