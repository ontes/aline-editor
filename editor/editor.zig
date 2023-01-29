const std = @import("std");
const render = @import("render");

const ImageSelection = @import("ImageSelection.zig");
const History = @import("History.zig");
const operations = @import("operations.zig");
const grabs = @import("grabs.zig");
const canvas = @import("canvas.zig");

pub var history: History = undefined;
pub var operation: ?operations.AnyOperation = null;
pub var grab: ?grabs.AnyGrab = null;

const live_preview = true;
pub var should_draw_canvas = true;
pub var should_draw_image = true;
pub var should_draw_helper = true;
pub var should_update_transform = true;

pub fn init(allocator: std.mem.Allocator) !void {
    history = History.init(allocator);
    try history.add(ImageSelection.init(allocator));
}

pub fn deinit() void {
    history.deinit();
}

fn applyOperation() !void {
    if (operation) |op| {
        if (!history.undo()) unreachable;
        try history.add(try op.apply(history.get().*));
        should_draw_helper = true;
        should_draw_image = true;
    }
}

pub fn updateOperation() !void {
    if (grab == null or live_preview)
        try applyOperation();
    should_draw_helper = true;
}

pub fn finishOperation() !void {
    if (grab != null and !live_preview)
        try applyOperation();
    operation = null;
    grab = null;
    should_draw_helper = true;
}

pub fn setOperation(new_operation: operations.AnyOperation) !void {
    try finishOperation();
    operation = new_operation;
    try history.add(try history.get().clone());
    try updateOperation();
}

const select_color = [4]f32{ 0.9, 0.9, 0, 1 };
const preview_color = [4]f32{ 0.9, 0, 0, 1 };

pub fn drawImage(buffer: *render.Buffer) !void {
    try history.get().image.draw(buffer);
}
pub fn drawHelper(buffer: *render.Buffer) !void {
    if (grab != null) {
        try operation.?.generateHelper(history.getPrev().*, buffer.generator(preview_color));
    } else {
        try history.get().generateSelected(canvas.wideStroke().generator(buffer.generator(select_color)));
    }
}
