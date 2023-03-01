const std = @import("std");
const Image = @import("Image.zig");

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

pub fn writeImage(file: std.fs.File, image: Image) !void {
    try writeAny(file, @as([]const usize, &.{image.props.len}));
    try writeAny(file, image.props.items(.node_count));
    try writeAny(file, image.props.items(.style));
    try writeAny(file, image.props.items(.name));
    try writeAny(file, @as([]const usize, &.{image.nodes.len}));
    try writeAny(file, image.nodes.items(.position));
    try writeAny(file, image.nodes.items(.angle));
}

pub fn readImage(file: std.fs.File, allocator: std.mem.Allocator) !Image {
    var image = Image.init(allocator);

    var props_len: [1]usize = undefined;
    try readAny(file, @as([]usize, &props_len));
    try image.props.resize(allocator, props_len[0]);
    try readAny(file, image.props.items(.node_count));
    try readAny(file, image.props.items(.style));
    try readAny(file, image.props.items(.name));

    var nodes_len: [1]usize = undefined;
    try readAny(file, @as([]usize, &nodes_len));
    try image.nodes.resize(allocator, nodes_len[0]);
    try readAny(file, image.nodes.items(.position));
    try readAny(file, image.nodes.items(.angle));

    return image;
}
