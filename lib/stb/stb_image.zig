const std = @import("std");

pub const STBI_default: c_int = 0;
pub const STBI_grey: c_int = 1;
pub const STBI_grey_alpha: c_int = 2;
pub const STBI_rgb: c_int = 3;
pub const STBI_rgb_alpha: c_int = 4;

pub const stbi_uc = u8;
pub const stbi_us = c_ushort;
pub const stbi_io_callbacks = extern struct {
    read: ?*const fn (?*anyopaque, [*c]u8, c_int) callconv(.C) c_int,
    skip: ?*const fn (?*anyopaque, c_int) callconv(.C) void,
    eof: ?*const fn (?*anyopaque) callconv(.C) c_int,
};
pub extern fn stbi_load_from_memory(buffer: [*c]const stbi_uc, len: c_int, x: [*c]c_int, y: [*c]c_int, channels_in_file: [*c]c_int, desired_channels: c_int) [*c]stbi_uc;
pub extern fn stbi_load_from_callbacks(clbk: [*c]const stbi_io_callbacks, user: ?*anyopaque, x: [*c]c_int, y: [*c]c_int, channels_in_file: [*c]c_int, desired_channels: c_int) [*c]stbi_uc;
pub extern fn stbi_load(filename: [*c]const u8, x: [*c]c_int, y: [*c]c_int, channels_in_file: [*c]c_int, desired_channels: c_int) [*c]stbi_uc;
pub extern fn stbi_load_from_file(f: [*c]std.c.FILE, x: [*c]c_int, y: [*c]c_int, channels_in_file: [*c]c_int, desired_channels: c_int) [*c]stbi_uc;
pub extern fn stbi_load_gif_from_memory(buffer: [*c]const stbi_uc, len: c_int, delays: [*c][*c]c_int, x: [*c]c_int, y: [*c]c_int, z: [*c]c_int, comp: [*c]c_int, req_comp: c_int) [*c]stbi_uc;
pub extern fn stbi_load_16_from_memory(buffer: [*c]const stbi_uc, len: c_int, x: [*c]c_int, y: [*c]c_int, channels_in_file: [*c]c_int, desired_channels: c_int) [*c]stbi_us;
pub extern fn stbi_load_16_from_callbacks(clbk: [*c]const stbi_io_callbacks, user: ?*anyopaque, x: [*c]c_int, y: [*c]c_int, channels_in_file: [*c]c_int, desired_channels: c_int) [*c]stbi_us;
pub extern fn stbi_load_16(filename: [*c]const u8, x: [*c]c_int, y: [*c]c_int, channels_in_file: [*c]c_int, desired_channels: c_int) [*c]stbi_us;
pub extern fn stbi_load_from_file_16(f: [*c]std.c.FILE, x: [*c]c_int, y: [*c]c_int, channels_in_file: [*c]c_int, desired_channels: c_int) [*c]stbi_us;
pub extern fn stbi_loadf_from_memory(buffer: [*c]const stbi_uc, len: c_int, x: [*c]c_int, y: [*c]c_int, channels_in_file: [*c]c_int, desired_channels: c_int) [*c]f32;
pub extern fn stbi_loadf_from_callbacks(clbk: [*c]const stbi_io_callbacks, user: ?*anyopaque, x: [*c]c_int, y: [*c]c_int, channels_in_file: [*c]c_int, desired_channels: c_int) [*c]f32;
pub extern fn stbi_loadf(filename: [*c]const u8, x: [*c]c_int, y: [*c]c_int, channels_in_file: [*c]c_int, desired_channels: c_int) [*c]f32;
pub extern fn stbi_loadf_from_file(f: [*c]std.c.FILE, x: [*c]c_int, y: [*c]c_int, channels_in_file: [*c]c_int, desired_channels: c_int) [*c]f32;
pub extern fn stbi_hdr_to_ldr_gamma(gamma: f32) void;
pub extern fn stbi_hdr_to_ldr_scale(scale: f32) void;
pub extern fn stbi_ldr_to_hdr_gamma(gamma: f32) void;
pub extern fn stbi_ldr_to_hdr_scale(scale: f32) void;
pub extern fn stbi_is_hdr_from_callbacks(clbk: [*c]const stbi_io_callbacks, user: ?*anyopaque) c_int;
pub extern fn stbi_is_hdr_from_memory(buffer: [*c]const stbi_uc, len: c_int) c_int;
pub extern fn stbi_is_hdr(filename: [*c]const u8) c_int;
pub extern fn stbi_is_hdr_from_file(f: [*c]std.c.FILE) c_int;
pub extern fn stbi_failure_reason() [*c]const u8;
pub extern fn stbi_image_free(retval_from_stbi_load: ?*anyopaque) void;
pub extern fn stbi_info_from_memory(buffer: [*c]const stbi_uc, len: c_int, x: [*c]c_int, y: [*c]c_int, comp: [*c]c_int) c_int;
pub extern fn stbi_info_from_callbacks(clbk: [*c]const stbi_io_callbacks, user: ?*anyopaque, x: [*c]c_int, y: [*c]c_int, comp: [*c]c_int) c_int;
pub extern fn stbi_is_16_bit_from_memory(buffer: [*c]const stbi_uc, len: c_int) c_int;
pub extern fn stbi_is_16_bit_from_callbacks(clbk: [*c]const stbi_io_callbacks, user: ?*anyopaque) c_int;
pub extern fn stbi_info(filename: [*c]const u8, x: [*c]c_int, y: [*c]c_int, comp: [*c]c_int) c_int;
pub extern fn stbi_info_from_file(f: [*c]std.c.FILE, x: [*c]c_int, y: [*c]c_int, comp: [*c]c_int) c_int;
pub extern fn stbi_is_16_bit(filename: [*c]const u8) c_int;
pub extern fn stbi_is_16_bit_from_file(f: [*c]std.c.FILE) c_int;
pub extern fn stbi_set_unpremultiply_on_load(flag_true_if_should_unpremultiply: c_int) void;
pub extern fn stbi_convert_iphone_png_to_rgb(flag_true_if_should_convert: c_int) void;
pub extern fn stbi_set_flip_vertically_on_load(flag_true_if_should_flip: c_int) void;
pub extern fn stbi_set_unpremultiply_on_load_thread(flag_true_if_should_unpremultiply: c_int) void;
pub extern fn stbi_convert_iphone_png_to_rgb_thread(flag_true_if_should_convert: c_int) void;
pub extern fn stbi_set_flip_vertically_on_load_thread(flag_true_if_should_flip: c_int) void;
pub extern fn stbi_zlib_decode_malloc_guesssize(buffer: [*c]const u8, len: c_int, initial_size: c_int, outlen: [*c]c_int) [*c]u8;
pub extern fn stbi_zlib_decode_malloc_guesssize_headerflag(buffer: [*c]const u8, len: c_int, initial_size: c_int, outlen: [*c]c_int, parse_header: c_int) [*c]u8;
pub extern fn stbi_zlib_decode_malloc(buffer: [*c]const u8, len: c_int, outlen: [*c]c_int) [*c]u8;
pub extern fn stbi_zlib_decode_buffer(obuffer: [*c]u8, olen: c_int, ibuffer: [*c]const u8, ilen: c_int) c_int;
pub extern fn stbi_zlib_decode_noheader_malloc(buffer: [*c]const u8, len: c_int, outlen: [*c]c_int) [*c]u8;
pub extern fn stbi_zlib_decode_noheader_buffer(obuffer: [*c]u8, olen: c_int, ibuffer: [*c]const u8, ilen: c_int) c_int;

pub const WriteFunc = *const fn (?*anyopaque, ?*anyopaque, c_int) callconv(.C) void;

pub extern var stbi_write_tga_with_rle: c_int;
pub extern var stbi_write_png_compression_level: c_int;
pub extern var stbi_write_force_png_filter: c_int;

extern fn stbi_write_png(filename: [*c]const u8, w: c_int, h: c_int, comp: c_int, data: ?*const anyopaque, stride_in_bytes: c_int) c_int;
pub const writePng = stbi_write_png;
extern fn stbi_write_bmp(filename: [*c]const u8, w: c_int, h: c_int, comp: c_int, data: ?*const anyopaque) c_int;
pub const writeBmp = stbi_write_bmp;
extern fn stbi_write_tga(filename: [*c]const u8, w: c_int, h: c_int, comp: c_int, data: ?*const anyopaque) c_int;
pub const writeTga = stbi_write_tga;
extern fn stbi_write_hdr(filename: [*c]const u8, w: c_int, h: c_int, comp: c_int, data: [*c]const f32) c_int;
pub const writeHdr = stbi_write_hdr;
extern fn stbi_write_jpg(filename: [*c]const u8, x: c_int, y: c_int, comp: c_int, data: ?*const anyopaque, quality: c_int) c_int;
pub const writeJpg = stbi_write_jpg;

extern fn stbi_write_png_to_func(func: WriteFunc, context: ?*anyopaque, w: c_int, h: c_int, comp: c_int, data: ?*const anyopaque, stride_in_bytes: c_int) c_int;
pub const writePngToFunc = stbi_write_png_to_func;
extern fn stbi_write_bmp_to_func(func: WriteFunc, context: ?*anyopaque, w: c_int, h: c_int, comp: c_int, data: ?*const anyopaque) c_int;
pub const writeBmpToFunc = stbi_write_bmp_to_func;
extern fn stbi_write_tga_to_func(func: WriteFunc, context: ?*anyopaque, w: c_int, h: c_int, comp: c_int, data: ?*const anyopaque) c_int;
pub const writeTgaToFunc = stbi_write_tga_to_func;
extern fn stbi_write_hdr_to_func(func: WriteFunc, context: ?*anyopaque, w: c_int, h: c_int, comp: c_int, data: [*c]const f32) c_int;
pub const writeHdrToFunc = stbi_write_hdr_to_func;
extern fn stbi_write_jpg_to_func(func: WriteFunc, context: ?*anyopaque, x: c_int, y: c_int, comp: c_int, data: ?*const anyopaque, quality: c_int) c_int;
pub const writeJpgToFunc = stbi_write_jpg_to_func;
extern fn stbi_flip_vertically_on_write(flip_boolean: c_int) void;
pub const flipVerticallyOnWrite = stbi_flip_vertically_on_write;
