const std = @import("std");
const render = @import("render.zig");
const geometry = @import("geometry.zig");
const platform = @import("platform.zig");
const vec2 = @import("linalg.zig").vec(2, f32);

const History = @import("editor/History.zig");
const operations = @import("editor/operations.zig");
const snapping = @import("editor/snapping.zig");
const input = @import("editor/input.zig");

const basic_stroke = geometry.Stroke{ .width = 0.005, .cap = .round };
const wide_stroke = geometry.Stroke{ .width = 0.01, .cap = .round };
const select_color = render.Color{ 255, 255, 64, 255 };

var history: History = undefined;
var pending_operation: ?operations.AnyOperation = null;

const live_preview = true;
var should_redraw_main = true;
var should_redraw_helper = true;

pub fn init(allocator: std.mem.Allocator) !void {
    history = History.init(allocator);
    try history.add(History.Entry.init(allocator));
}

pub fn deinit() void {
    history.deinit();
}

fn isGrabbed() bool {
    return pending_operation != null and pending_operation.?.isGrabbed();
}

fn applyOperation() !void {
    if (pending_operation) |operation| {
        if (!history.undo()) unreachable;
        try history.add(try operation.apply(history.get().*));
        should_redraw_helper = true;
        should_redraw_main = true;
    }
}

pub fn updateOperation() !void {
    if (live_preview or !isGrabbed())
        try applyOperation();
    should_redraw_helper = true;
}

fn setOperation(operation: operations.AnyOperation) !void {
    pending_operation = operation;
    try history.add(try history.get().clone());
    try updateOperation();
}

fn select() !void {
    const selection = &history.get().selection;
    if (!input.isShiftPressed())
        selection.clear();
    if (snapping.select(history.get().drawing, input.mouseCanvasPos())) |s| {
        const path = history.get().drawing.getPath(s.index);
        if (input.isCtrlPressed()) {
            try selection.toggleWhole(s.index, path);
        } else switch (s.val) {
            .node => |node| try selection.toggleNode(s.index, node, path),
            .segment => |segment| try selection.toggleSegment(s.index, segment, path),
            .loop => try selection.toggleWhole(s.index, path),
        }
    }
}

pub fn onEvent(event: platform.Event) !void {
    input.onEvent(event);
    if (pending_operation) |*operation|
        try operation.onEvent(event);
    switch (event) {
        .key_press => |key| {
            if (!live_preview and isGrabbed())
                try applyOperation();
            switch (key) {
                .mouse_left => if (!isGrabbed()) {
                    try select();
                    pending_operation = null;
                    should_redraw_helper = true;
                },
                .z => if (input.isCtrlPressed()) {
                    if (history.undo()) {
                        pending_operation = null;
                        should_redraw_main = true;
                        should_redraw_helper = true;
                    }
                },
                .y => if (input.isCtrlPressed()) {
                    if (history.redo()) {
                        pending_operation = null;
                        should_redraw_main = true;
                        should_redraw_helper = true;
                    }
                },
                .a => if (input.isCtrlPressed()) {
                    if (!isGrabbed()) {
                        try history.get().selection.selectAll(history.get().drawing);
                        pending_operation = null;
                        should_redraw_helper = true;
                    }
                } else if (operations.AddPoint.init(history.get().*)) |op| {
                    try setOperation(.{ .AddPoint = op });
                } else if (operations.Append.init(history.get().*)) |op| {
                    try setOperation(.{ .Append = op });
                },
                .c => if (operations.Connect.init(history.get().*)) |op| {
                    try setOperation(.{ .Connect = op });
                },
                .g => if (operations.Move.init(history.get().*)) |op| {
                    try setOperation(.{ .Move = op });
                },
                .d => if (operations.ChangeAngle.init(history.get().*)) |op| {
                    try setOperation(.{ .ChangeAngle = op });
                },
                .delete => if (operations.Delete.init(history.get().*)) |op| {
                    try setOperation(.{ .Delete = op });
                },
                else => {},
            }
        },
        else => {},
    }
}

pub fn draw(main_buffer: *render.Buffer, helper_buffer: *render.Buffer) !bool {
    if (!should_redraw_main and !should_redraw_helper)
        return false;
    if (should_redraw_main) {
        main_buffer.clear();
        try history.get().drawing.draw(main_buffer);
        main_buffer.flush();
        should_redraw_main = false;
    }
    if (should_redraw_helper) {
        helper_buffer.clear();
        if (pending_operation != null and pending_operation.?.isGrabbed()) {
            try pending_operation.?.drawHelper(history.getPrev().*, helper_buffer);
        } else {
            try history.get().selection.draw(history.get().drawing, wide_stroke, select_color, helper_buffer);
        }
        helper_buffer.flush();
        should_redraw_helper = false;
    }
    return true;
}
