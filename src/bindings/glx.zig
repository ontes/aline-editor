const std = @import("std");
const x11 = @import("x11.zig");

pub const Context = *opaque {};
pub const Pixmap = *opaque {};
pub const Drawable = *anyopaque;
pub const FBConfig = *opaque {};
pub const FBConfigID = *opaque {};
pub const ContextID = *opaque {};
pub const Window = *opaque {};
pub const Pbuffer = *opaque {};

pub const use_gl = 1;
pub const buffer_size = 2;
pub const level = 3;
pub const rgba = 4;
pub const doublebuffer = 5;
pub const stereo = 6;
pub const aux_buffers = 7;
pub const red_size = 8;
pub const green_size = 9;
pub const blue_size = 10;
pub const alpha_size = 11;
pub const depth_size = 12;
pub const stencil_size = 13;
pub const accum_red_size = 14;
pub const accum_green_size = 15;
pub const accum_blue_size = 16;
pub const accum_alpha_size = 17;

pub const ErrorName = enum(c_int) {
    bad_screen = 1,
    bad_attribute = 2,
    no_extension = 3,
    bad_visual = 4,
    bad_context = 5,
    bad_value = 6,
    bad_enum = 7,
};

pub const ClientStringName = enum(c_int) {
    vendor = 1,
    version = 2,
    extensions = 3,
};

pub const config_caveat = 0x20;
pub const dont_care = std.math.maxint(u32);
pub const x_visual_type = 0x22;
pub const transparent_type = 0x23;
pub const transparent_index_value = 0x24;
pub const transparent_red_value = 0x25;
pub const transparent_green_value = 0x26;
pub const transparent_blue_value = 0x27;
pub const transparent_alpha_value = 0x28;

pub const window_bit = 0x00000001;
pub const pixmap_bit = 0x00000002;
pub const pbuffer_bit = 0x00000004;
pub const aux_buffers_bit = 0x00000010;
pub const front_left_buffer_bit = 0x00000001;
pub const front_right_buffer_bit = 0x00000002;
pub const back_left_buffer_bit = 0x00000004;
pub const back_right_buffer_bit = 0x00000008;
pub const depth_buffer_bit = 0x00000020;
pub const stencil_buffer_bit = 0x00000040;
pub const accum_buffer_bit = 0x00000080;

pub const none = 0x8000;
pub const slow_config = 0x8001;
pub const true_color = 0x8002;
pub const direct_color = 0x8003;
pub const pseudo_color = 0x8004;
pub const static_color = 0x8005;
pub const gray_scale = 0x8006;
pub const static_gray = 0x8007;
pub const transparent_rgb = 0x8008;
pub const transparent_index = 0x8009;
pub const visual_id = 0x800b;
pub const screen = 0x800c;
pub const non_conformant_config = 0x800d;
pub const drawable_type = 0x8010;
pub const render_type = 0x8011;
pub const x_renderable = 0x8012;
pub const fbconfig_id = 0x8013;

pub const RenderType = enum(c_int) {
    rgba_type = 0x8014,
    color_index_type = 0x8015,
};

pub const max_pbuffer_width = 0x8016;
pub const max_pbuffer_height = 0x8017;
pub const max_pbuffer_pixels = 0x8018;
pub const preserved_contents = 0x801b;
pub const largest_pbuffer = 0x801c;
pub const width = 0x801d;
pub const height = 0x801e;
pub const event_mask = 0x801f;
pub const damaged = 0x8020;
pub const saved = 0x8021;
pub const window = 0x8022;
pub const pbuffer = 0x8023;
pub const pbuffer_height = 0x8040;
pub const pbuffer_width = 0x8041;

pub const rgba_bit = 0x00000001;
pub const color_index_bit = 0x00000002;

pub const sample_buffers = 0x186a0;
pub const samples = 0x186a1;

pub const chooseVisual = glXChooseVisual;
pub const createContext = glXCreateContext;
pub const destroyContext = glXDestroyContext;
pub const makeCurrent = glXMakeCurrent;
pub const copyContext = glXCopyContext;
pub const swapBuffers = glXSwapBuffers;
pub const createGLXPixmap = glXCreateGLXPixmap;
pub const destroyGLXPixmap = glXDestroyGLXPixmap;
pub const queryExtension = glXQueryExtension;
pub const queryVersion = glXQueryVersion;
pub const isDirect = glXIsDirect;
pub const getConfig = glXGetConfig;
pub const getCurrentContext = glXGetCurrentContext;
pub const getCurrentDrawable = glXGetCurrentDrawable;
pub const waitGL = glXWaitGL;
pub const waitX = glXWaitX;
pub const useXFont = glXUseXFont;
pub const queryExtensionsString = glXQueryExtensionsString;
pub const queryServerString = glXQueryServerString;
pub const getClientString = glXGetClientString;
pub const getCurrentDisplay = glXGetCurrentDisplay;
pub const chooseFBConfig = glXChooseFBConfig;
pub const getFBConfigAttrib = glXGetFBConfigAttrib;
pub const getFBConfigs = glXGetFBConfigs;
pub const getVisualFromFBConfig = glXGetVisualFromFBConfig;
pub const createWindow = glXCreateWindow;
pub const destroyWindow = glXDestroyWindow;
pub const createPixmap = glXCreatePixmap;
pub const destroyPixmap = glXDestroyPixmap;
pub const createPbuffer = glXCreatePbuffer;
pub const destroyPbuffer = glXDestroyPbuffer;
pub const queryDrawable = glXQueryDrawable;
pub const createNewContext = glXCreateNewContext;
pub const makeContextCurrent = glXMakeContextCurrent;
pub const getCurrentReadDrawable = glXGetCurrentReadDrawable;
pub const queryContext = glXQueryContext;
pub const selectEvent = glXSelectEvent;
pub const getSelectedEvent = glXGetSelectedEvent;

extern fn glXChooseVisual(display: x11.Display, screen: c_int, attrib_list: [*:0]c_int) *x11.VisualInfo;
extern fn glXCreateContext(display: x11.Display, vis: *x11.VisualInfo, share_list: Context, direct: c_int) Context;
extern fn glXDestroyContext(display: x11.Display, ctx: Context) void;
extern fn glXMakeCurrent(display: x11.Display, drawable: Drawable, ctx: Context) x11.Bool;
extern fn glXCopyContext(display: x11.Display, src: Context, dst: Context, mask: c_ulong) void;
extern fn glXSwapBuffers(display: x11.Display, drawable: Drawable) void;
extern fn glXCreateGLXPixmap(display: x11.Display, visual: *x11.VisualInfo, pixmap: Pixmap) Pixmap;
extern fn glXDestroyGLXPixmap(display: x11.Display, pixmap: Pixmap) void;
extern fn glXQueryExtension(display: x11.Display, errorb: [*c]c_int, event: [*c]c_int) c_int;
extern fn glXQueryVersion(display: x11.Display, maj: [*c]c_int, min: [*c]c_int) c_int;
extern fn glXIsDirect(display: x11.Display, ctx: Context) c_int;
extern fn glXGetConfig(display: x11.Display, visual: *x11.VisualInfo, attrib: c_int, value: [*c]c_int) c_int;
extern fn glXGetCurrentContext() Context;
extern fn glXGetCurrentDrawable() Drawable;
extern fn glXWaitGL() void;
extern fn glXWaitX() void;
extern fn glXUseXFont(font: x11.Font, first: c_int, count: c_int, list: c_int) void;
extern fn glXQueryExtensionsString(display: x11.Display, screen: c_int) [*:0]const u8;
extern fn glXQueryServerString(display: x11.Display, screen: c_int, name: c_int) [*:0]const u8;
extern fn glXGetClientString(display: x11.Display, name: ClientStringName) [*:0]const u8;
extern fn glXGetCurrentDisplay() ?x11.Display;
extern fn glXChooseFBConfig(display: x11.Display, screen: c_int, attrib_list: [*:0]const c_int, nelements: *c_int) [*]FBConfig;
extern fn glXGetFBConfigAttrib(display: x11.Display, config: FBConfig, attribute: c_int, value: [*c]c_int) c_int;
extern fn glXGetFBConfigs(display: x11.Display, screen: c_int, nelements: *c_int) [*]FBConfig;
extern fn glXGetVisualFromFBConfig(display: x11.Display, config: FBConfig) ?*x11.VisualInfo;
extern fn glXCreateWindow(display: x11.Display, config: FBConfig, win: Window, attrib_list: [*:0]const c_int) Window;
extern fn glXDestroyWindow(display: x11.Display, window: Window) void;
extern fn glXCreatePixmap(display: x11.Display, config: FBConfig, pixmap: Pixmap, attrib_list: [*:0]const c_int) Pixmap;
extern fn glXDestroyPixmap(display: x11.Display, pixmap: Pixmap) void;
extern fn glXCreatePbuffer(display: x11.Display, config: FBConfig, attrib_list: [*:0]const c_int) Pbuffer;
extern fn glXDestroyPbuffer(display: x11.Display, pbuf: Pbuffer) void;
extern fn glXQueryDrawable(display: x11.Display, draw: Drawable, attribute: c_int, value: [*c]c_uint) void;
extern fn glXCreateNewContext(display: x11.Display, config: FBConfig, render_type: RenderType, share_list: ?Context, direct: x11.Bool) ?Context;
extern fn glXMakeContextCurrent(display: x11.Display, draw: Drawable, read: Drawable, ctx: Context) x11.Bool;
extern fn glXGetCurrentReadDrawable() Drawable;
extern fn glXQueryContext(display: x11.Display, ctx: Context, attribute: c_int, value: [*c]c_int) c_int;
extern fn glXSelectEvent(display: x11.Display, drawable: Drawable, mask: c_ulong) void;
extern fn glXGetSelectedEvent(display: x11.Display, drawable: Drawable, mask: [*c]c_ulong) void;
extern fn glXGetProcAddress(proc_name: [*:0]const u8) ?*const fn () callconv(.C) void;
