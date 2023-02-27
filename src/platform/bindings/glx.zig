const std = @import("std");
const x11 = @import("x11.zig");

pub const Context = opaque {};
pub const Pixmap = x11.ID;
pub const Drawable = x11.ID;
pub const FBConfig = opaque {};
pub const FBConfigID = x11.ID;
pub const ContextID = x11.ID;
pub const Window = x11.ID;
pub const Pbuffer = x11.ID;

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

extern fn glXChooseVisual(display: *x11.Display, screen: c_int, attrib_list: [*:0]c_int) *x11.VisualInfo;
pub const chooseVisual = glXChooseVisual;
extern fn glXCreateContext(display: *x11.Display, vis: *x11.VisualInfo, share_list: *Context, direct: c_int) *Context;
pub const createContext = glXCreateContext;
extern fn glXDestroyContext(display: *x11.Display, ctx: *Context) void;
pub const destroyContext = glXDestroyContext;
extern fn glXMakeCurrent(display: *x11.Display, drawable: Drawable, ctx: *Context) x11.Bool;
pub const makeCurrent = glXMakeCurrent;
extern fn glXCopyContext(display: *x11.Display, src: *Context, dst: *Context, mask: c_ulong) void;
pub const copyContext = glXCopyContext;
extern fn glXSwapBuffers(display: *x11.Display, drawable: Drawable) void;
pub const swapBuffers = glXSwapBuffers;
extern fn glXCreateGLXPixmap(display: *x11.Display, visual: *x11.VisualInfo, pixmap: Pixmap) Pixmap;
pub const createGLXPixmap = glXCreateGLXPixmap;
extern fn glXDestroyGLXPixmap(display: *x11.Display, pixmap: Pixmap) void;
pub const destroyGLXPixmap = glXDestroyGLXPixmap;
extern fn glXQueryExtension(display: *x11.Display, errorb: [*c]c_int, event: [*c]c_int) c_int;
pub const queryExtension = glXQueryExtension;
extern fn glXQueryVersion(display: *x11.Display, maj: [*c]c_int, min: [*c]c_int) c_int;
pub const queryVersion = glXQueryVersion;
extern fn glXIsDirect(display: *x11.Display, ctx: *Context) c_int;
pub const isDirect = glXIsDirect;
extern fn glXGetConfig(display: *x11.Display, visual: *x11.VisualInfo, attrib: c_int, value: [*c]c_int) c_int;
pub const getConfig = glXGetConfig;
extern fn glXGetCurrentContext() *Context;
pub const getCurrentContext = glXGetCurrentContext;
extern fn glXGetCurrentDrawable() Drawable;
pub const getCurrentDrawable = glXGetCurrentDrawable;
extern fn glXWaitGL() void;
pub const waitGL = glXWaitGL;
extern fn glXWaitX() void;
pub const waitX = glXWaitX;
extern fn glXUseXFont(font: x11.Font, first: c_int, count: c_int, list: c_int) void;
pub const useXFont = glXUseXFont;
extern fn glXQueryExtensionsString(display: *x11.Display, screen: c_int) [*:0]const u8;
pub const queryExtensionsString = glXQueryExtensionsString;
extern fn glXQueryServerString(display: *x11.Display, screen: c_int, name: c_int) [*:0]const u8;
pub const queryServerString = glXQueryServerString;
extern fn glXGetClientString(display: *x11.Display, name: ClientStringName) [*:0]const u8;
pub const getClientString = glXGetClientString;
extern fn glXGetCurrentDisplay() ?*x11.Display;
pub const getCurrentDisplay = glXGetCurrentDisplay;
extern fn glXChooseFBConfig(display: *x11.Display, screen: c_int, attrib_list: [*:0]const c_int, nelements: *c_int) [*]*FBConfig;
pub const chooseFBConfig = glXChooseFBConfig;
extern fn glXGetFBConfigAttrib(display: *x11.Display, config: *FBConfig, attribute: c_int, value: [*c]c_int) c_int;
pub const getFBConfigAttrib = glXGetFBConfigAttrib;
extern fn glXGetFBConfigs(display: *x11.Display, screen: c_int, nelements: *c_int) [*]*FBConfig;
pub const getFBConfigs = glXGetFBConfigs;
extern fn glXGetVisualFromFBConfig(display: *x11.Display, config: *FBConfig) ?*x11.VisualInfo;
pub const getVisualFromFBConfig = glXGetVisualFromFBConfig;
extern fn glXCreateWindow(display: *x11.Display, config: *FBConfig, win: Window, attrib_list: [*:0]const c_int) Window;
pub const createWindow = glXCreateWindow;
extern fn glXDestroyWindow(display: *x11.Display, window: Window) void;
pub const destroyWindow = glXDestroyWindow;
extern fn glXCreatePixmap(display: *x11.Display, config: *FBConfig, pixmap: Pixmap, attrib_list: [*:0]const c_int) Pixmap;
pub const createPixmap = glXCreatePixmap;
extern fn glXDestroyPixmap(display: *x11.Display, pixmap: Pixmap) void;
pub const destroyPixmap = glXDestroyPixmap;
extern fn glXCreatePbuffer(display: *x11.Display, config: *FBConfig, attrib_list: [*:0]const c_int) Pbuffer;
pub const createPbuffer = glXCreatePbuffer;
extern fn glXDestroyPbuffer(display: *x11.Display, pbuf: Pbuffer) void;
pub const destroyPbuffer = glXDestroyPbuffer;
extern fn glXQueryDrawable(display: *x11.Display, draw: Drawable, attribute: c_int, value: [*c]c_uint) void;
pub const queryDrawable = glXQueryDrawable;
extern fn glXCreateNewContext(display: *x11.Display, config: *FBConfig, render_type: RenderType, share_list: ?*Context, direct: x11.Bool) ?*Context;
pub const createNewContext = glXCreateNewContext;
extern fn glXMakeContextCurrent(display: *x11.Display, draw: Drawable, read: Drawable, ctx: *Context) x11.Bool;
pub const makeContextCurrent = glXMakeContextCurrent;
extern fn glXGetCurrentReadDrawable() Drawable;
pub const getCurrentReadDrawable = glXGetCurrentReadDrawable;
extern fn glXQueryContext(display: *x11.Display, ctx: *Context, attribute: c_int, value: [*c]c_int) c_int;
pub const queryContext = glXQueryContext;
extern fn glXSelectEvent(display: *x11.Display, drawable: Drawable, mask: c_ulong) void;
pub const selectEvent = glXSelectEvent;
extern fn glXGetSelectedEvent(display: *x11.Display, drawable: Drawable, mask: [*c]c_ulong) void;
pub const getSelectedEvent = glXGetSelectedEvent;
extern fn glXGetProcAddress(proc_name: [*:0]const u8) ?*const fn () callconv(.C) void;
pub const getProcAddress = glXGetProcAddress;
