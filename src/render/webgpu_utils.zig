const std = @import("std");
const webgpu = @import("../bindings/webgpu.zig");
const platform = @import("../platform.zig");

const err = error.RendererError;

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

pub fn createAdapter(instance: webgpu.Instance, surface: webgpu.Surface) !webgpu.Adapter {
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

pub fn createDevice(adapter: webgpu.Adapter) !webgpu.Device {
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

    return response.device.?;
}

pub fn createSwapchain(device: webgpu.Device, surface: webgpu.Surface, size: [2]u32) webgpu.SwapChain {
    return device.createSwapChain(surface, &.{
        .usage = .{ .render_attachment = true },
        .format = .bgra8_unorm,
        .width = size[0],
        .height = size[1],
        .present_mode = .fifo,
    });
}
