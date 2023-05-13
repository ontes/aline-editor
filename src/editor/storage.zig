const std = @import("std");
const nfd = @import("nfd");

const Image = @import("Image.zig");
const editor = @import("editor.zig");
const rendering = @import("rendering.zig");

const signature = [5]u8{ 'a', 'l', 'i', 'n', 'e' };

pub var last_save_path: ?[*:0]u8 = null;
pub var last_export_path: ?[*:0]u8 = null;

pub fn deinit() void {
    std.c.free(last_save_path);
    std.c.free(last_export_path);
}

fn toByteSlice(comptime Type: type, slice: []Type) []u8 {
    return @ptrCast([*]u8, slice.ptr)[0..(slice.len * @sizeOf(Type))];
}

fn toByteSliceConst(comptime Type: type, slice: []const Type) []const u8 {
    return @ptrCast([*]const u8, slice.ptr)[0..(slice.len * @sizeOf(Type))];
}

fn readAny(file: std.fs.File, data: anytype) !void {
    if (try file.readAll(toByteSlice(@TypeOf(data[0]), data)) != data.len * @sizeOf(@TypeOf(data[0])))
        return error.EndOfFile;
}

fn writeAny(file: std.fs.File, data: anytype) !void {
    try file.writeAll(toByteSliceConst(@TypeOf(data[0]), data));
}

pub fn loadFromFile(path: [*:0]const u8) !void {
    const file = try std.fs.openFileAbsoluteZ(path, .{});
    defer file.close();

    var signature_check: [5]u8 = undefined;
    try readAny(file, &signature_check);
    if (!std.mem.eql(u8, &signature, &signature_check))
        return error.InvalidFileType;

    try readAny(file, &editor.canvas_size);
    try readAny(file, &editor.canvas_color);

    var image = Image.init(editor.history.get().image.allocator);

    var props_len: [1]usize = undefined;
    try readAny(file, @as([]usize, &props_len));
    try image.props.resize(image.allocator, props_len[0]);
    try readAny(file, image.props.items(.node_count));
    try readAny(file, image.props.items(.style));
    try readAny(file, image.props.items(.name));

    var nodes_len: [1]usize = undefined;
    try readAny(file, @as([]usize, &nodes_len));
    try image.nodes.resize(image.allocator, nodes_len[0]);
    try readAny(file, image.nodes.items(.position));
    try readAny(file, image.nodes.items(.angle));

    editor.history.clear();
    try editor.history.add(.{ .image = image });

    editor.should_draw_image = true;
    editor.should_draw_helper = true;
    editor.should_draw_canvas = true;
}

pub fn saveToFile(path: [*:0]const u8) !void {
    const file = try std.fs.createFileAbsoluteZ(path, .{});
    defer file.close();

    try writeAny(file, &signature);
    try writeAny(file, &editor.canvas_size);
    try writeAny(file, &editor.canvas_color);

    const image = editor.history.get().image;

    try writeAny(file, @as([]const usize, &.{image.props.len}));
    try writeAny(file, image.props.items(.node_count));
    try writeAny(file, image.props.items(.style));
    try writeAny(file, image.props.items(.name));
    try writeAny(file, @as([]const usize, &.{image.nodes.len}));
    try writeAny(file, image.nodes.items(.position));
    try writeAny(file, image.nodes.items(.angle));
}

pub fn exportToFile(path: [*:0]const u8) !void {
    try rendering.renderToFile(path, editor.canvas_size, editor.canvas_color);
}

pub fn load() !void {
    var path: [*:0]u8 = undefined;
    if (nfd.openDialog(null, null, &path) == .okay) {
        try loadFromFile(path);
        std.c.free(last_save_path);
        last_save_path = path;
    }
}

pub fn save() !void {
    if (last_save_path) |path| {
        return saveToFile(path);
    } else {
        return saveAs();
    }
}

pub fn saveAs() !void {
    var path: [*:0]u8 = undefined;
    if (nfd.saveDialog(null, "image.bin", &path) == .okay) {
        try saveToFile(path);
        std.c.free(last_save_path);
        last_save_path = path;
    }
}

pub fn export_() !void {
    if (last_save_path) |path| {
        return exportToFile(path);
    } else {
        return exportAs();
    }
}

pub fn exportAs() !void {
    var path: [*:0]u8 = undefined;
    if (nfd.saveDialog(null, "image.png", &path) == .okay) {
        try exportToFile(path);
        std.c.free(last_export_path);
        last_export_path = path;
    }
}
