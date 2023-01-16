const std = @import("std");
const math = @import("math");
const platform = @import("platform");
const render = @import("render");

const Selection = @import("Selection.zig");
const History = @import("History.zig");
const operations = @import("operations.zig");
const snapping = @import("snapping.zig");
const input = @import("input.zig");
const ui = @import("ui.zig");

const select_color = [4]u8{ 255, 255, 64, 255 };
const preview_color = [4]u8{ 255, 64, 64, 255 };

var history: History = undefined;
var pending_operation: ?operations.AnyOperation = null;

const live_preview = true;

var should_redraw = true;
var should_redraw_canvas = true;
var should_redraw_main = true;
var should_redraw_helper = true;
var should_update_transform = true;

var mouse_click_pos: ?math.Vec2 = null;

pub fn init(allocator: std.mem.Allocator, context: render.Context) !void {
    history = History.init(allocator);
    try history.add(Selection.init(allocator));
    ui.init(context);
}

pub fn deinit() void {
    ui.deinit();
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

fn finishOperation() !void {
    if (isGrabbed()) {
        if (!live_preview) try applyOperation();
        should_redraw_helper = true;
    }
    pending_operation = null;
}

fn setOperation(operation: operations.AnyOperation) !void {
    try finishOperation();
    pending_operation = operation;
    try history.add(try history.get().clone());
    try updateOperation();
}

fn selectPoint(pos: math.Vec2) !void {
    const sel = history.get();
    if (snapping.select(sel.drawing, pos)) |s| {
        if (input.isCtrlPressed()) {
            try sel.togglePath(s.index);
        } else switch (s.val) {
            .node => |node| try sel.toggleNode(s.index, node),
            .segment => |segment| try sel.toggleSegment(s.index, segment),
            .loop => try sel.togglePath(s.index),
        }
    }
}

fn selectRect(min_pos: math.Vec2, max_pos: math.Vec2) !void {
    const sel = history.get();
    var it = sel.drawing.pathIterator();
    while (it.next()) |path| {
        var i: u32 = 0;
        while (i < path.len()) : (i += 1) {
            if (@reduce(.And, path.positions[i] >= min_pos) and
                @reduce(.And, path.positions[i] <= max_pos) and
                !sel.isSelectedNode(it.getIndex(), i))
                try sel.selectNode(it.getIndex(), i);
        }
        i = 0;
        while (i < path.angles.len) : (i += 1) {
            const arc = path.getArc(i);
            const arc_bounds = arc.boundingBox();
            if (@reduce(.And, arc_bounds[0] >= min_pos) and
                @reduce(.And, arc_bounds[1] <= max_pos) and
                !sel.isSelectedSegment(it.getIndex(), i))
                try sel.selectSegment(it.getIndex(), i);
        }
    }
}

pub fn onEvent(event: platform.Event) !void {
    should_redraw = true;
    input.onEvent(event);
    ui.handleEvent(event);
    switch (event) {
        .key_press => |key| switch (key) {
            .mouse_left => if (!isGrabbed() and !ui.isMouseCaptured()) {
                mouse_click_pos = input.mouseCanvasPos();
            },
            else => {},
        },
        .key_release => |key| switch (key) {
            .mouse_left => if (!isGrabbed() and !ui.isMouseCaptured() and mouse_click_pos != null) {
                try finishOperation();

                if (!input.isShiftPressed())
                    history.get().deselectAll();

                const mouse_pos = input.mouseCanvasPos();
                if (snapping.shouldSnapToPoint(mouse_pos, mouse_click_pos.?)) {
                    try selectPoint(mouse_click_pos.?);
                } else {
                    try selectRect(@min(mouse_pos, mouse_click_pos.?), @max(mouse_pos, mouse_click_pos.?));
                }

                should_redraw_helper = true;
                mouse_click_pos = null;
            },
            .z => {
                try finishOperation();
                if (input.isCtrlPressed() and history.undo()) {
                    should_redraw_main = true;
                    should_redraw_helper = true;
                }
            },
            .y => {
                try finishOperation();
                if (input.isCtrlPressed() and history.redo()) {
                    should_redraw_main = true;
                    should_redraw_helper = true;
                }
            },
            .a => {
                try finishOperation();
                if (input.isCtrlPressed()) {
                    try history.get().selectAll();
                    should_redraw_helper = true;
                } else if (operations.AddPoint.init(history.get().*)) |op| {
                    try setOperation(.{ .AddPoint = op });
                } else if (operations.Append.init(history.get().*)) |op| {
                    try setOperation(.{ .Append = op });
                }
            },
            .c => {
                try finishOperation();
                if (operations.Connect.init(history.get().*)) |op|
                    try setOperation(.{ .Connect = op });
            },
            .g => {
                try finishOperation();
                if (operations.Move.init(history.get().*)) |op|
                    try setOperation(.{ .Move = op });
            },
            .d => {
                try finishOperation();
                if (operations.ChangeAngle.init(history.get().*)) |op|
                    try setOperation(.{ .ChangeAngle = op });
            },
            .delete => {
                try finishOperation();
                if (operations.Remove.init(history.get().*)) |op|
                    try setOperation(.{ .Remove = op });
            },
            else => {},
        },
        .window_resize => {
            should_update_transform = true;
            should_redraw_helper = true;
        },
        .mouse_move => {
            if (input.isMouseMiddlePressed()) {
                input.canvas_pan -= input.mouseCanvasOffset();
                should_update_transform = true;
            }
        },
        .mouse_scroll => |offset| {
            input.canvas_zoom *= std.math.pow(f32, 0.8, @intToFloat(f32, offset));
            should_update_transform = true;
            should_redraw_helper = true;
        },
        else => {},
    }
    if (pending_operation) |*operation|
        try operation.onEvent(event);
}

pub fn redraw(
    canvas_buffer: *render.Buffer,
    main_buffer: *render.Buffer,
    helper_buffer: *render.Buffer,
) !bool {
    if (!should_redraw and !should_redraw_canvas and !should_redraw_main and !should_redraw_helper and !should_update_transform)
        return false;

    ui.update(&pending_operation);
    should_redraw = false;

    if (should_redraw_canvas) {
        canvas_buffer.clear();
        try drawCanvas(canvas_buffer);
        canvas_buffer.flush();
        should_redraw_canvas = false;
    }

    if (should_redraw_main) {
        main_buffer.clear();
        try history.get().drawing.draw(main_buffer);
        main_buffer.flush();
        should_redraw_main = false;
    }

    if (should_redraw_helper) {
        helper_buffer.clear();
        if (isGrabbed()) {
            try pending_operation.?.generateHelper(history.getPrev().*, helper_buffer.generator(preview_color));
        } else {
            try history.get().generateSelected(input.wideStroke().generator(helper_buffer.generator(select_color)));
        }
        helper_buffer.flush();
        should_redraw_helper = false;
    }

    if (should_update_transform) {
        main_buffer.setTransform(input.canvasTransform());
        helper_buffer.setTransform(input.canvasTransform());
        canvas_buffer.setTransform(input.canvasTransform());
        should_update_transform = false;
    }
    return true;
}

const canvas_size = math.Vec2{ 512, 512 };
const canvas_corner_radius: f32 = 16;

pub fn drawCanvas(buffer: *render.Buffer) !void {
    const rect = math.RoundedRect{
        .pos = .{ 0, 0 },
        .radius = canvas_size / math.vec2.splat(2),
        .corner_radius = canvas_corner_radius,
    };
    try rect.generate(buffer.generator(.{ 255, 255, 255, 255 }));
}
