const std = @import("std");
const Image = @import("Image.zig");

const signature = [5]u8{ 'a', 'l', 'i', 'n', 'e' };

fn toByteSlice(comptime Type: type, slice: []Type) []u8 {
    return @ptrCast([*]u8, slice.ptr)[0..(slice.len * @sizeOf(Type))];
}

fn toByteSliceConst(comptime Type: type, slice: []const Type) []const u8 {
    return @ptrCast([*]const u8, slice.ptr)[0..(slice.len * @sizeOf(Type))];
}

fn writeAny(file: std.fs.File, data: anytype) !void {
    try file.writeAll(toByteSliceConst(@TypeOf(data[0]), data));
}

fn readAny(file: std.fs.File, data: anytype) !void {
    if (try file.readAll(toByteSlice(@TypeOf(data[0]), data)) != data.len * @sizeOf(@TypeOf(data[0])))
        return error.EndOfFile;
}

const ImageInfo = struct {
    image: Image,
    canvas_size: [2]u32,
    canvas_color: [4]f32,
};

pub fn writeImage(file: std.fs.File, ii: ImageInfo) !void {
    try writeAny(file, &signature);
    try writeAny(file, &ii.canvas_size);
    try writeAny(file, &ii.canvas_color);
    try writeAny(file, @as([]const usize, &.{ii.image.props.len}));
    try writeAny(file, ii.image.props.items(.node_count));
    try writeAny(file, ii.image.props.items(.style));
    try writeAny(file, ii.image.props.items(.name));
    try writeAny(file, @as([]const usize, &.{ii.image.nodes.len}));
    try writeAny(file, ii.image.nodes.items(.position));
    try writeAny(file, ii.image.nodes.items(.angle));
}

pub fn readImage(file: std.fs.File, allocator: std.mem.Allocator) !ImageInfo {
    var signature_check: [5]u8 = undefined;
    try readAny(file, &signature_check);
    if (!std.mem.eql(u8, &signature, &signature_check))
        return error.InvalidFileType;

    var ii = ImageInfo{ .image = Image.init(allocator), .canvas_size = undefined, .canvas_color = undefined };
    try readAny(file, &ii.canvas_size);
    try readAny(file, &ii.canvas_color);

    var props_len: [1]usize = undefined;
    try readAny(file, @as([]usize, &props_len));
    try ii.image.props.resize(allocator, props_len[0]);
    try readAny(file, ii.image.props.items(.node_count));
    try readAny(file, ii.image.props.items(.style));
    try readAny(file, ii.image.props.items(.name));

    var nodes_len: [1]usize = undefined;
    try readAny(file, @as([]usize, &nodes_len));
    try ii.image.nodes.resize(allocator, nodes_len[0]);
    try readAny(file, ii.image.nodes.items(.position));
    try readAny(file, ii.image.nodes.items(.angle));

    return ii;
}
