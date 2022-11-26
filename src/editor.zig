const std = @import("std");
const render = @import("render.zig");
const geometry = @import("geometry.zig");
const platform = @import("platform.zig");

const Selection = @import("editor/Selection.zig");
const History = @import("editor/History.zig");
const operations = @import("editor/operations.zig");
const snapping = @import("editor/snapping.zig");
const input = @import("editor/input.zig");

const select_color = render.Color{ 255, 255, 64, 255 };

var history: History = undefined;
var pending_operation: ?operations.AnyOperation = null;

const live_preview = false;
var should_redraw_main = true;
var should_redraw_helper = true;
var should_update_transform = true;

var mouse_click_pos: ?geometry.Vec2 = null;

pub fn init(allocator: std.mem.Allocator) !void {
    history = History.init(allocator);
    try history.add(Selection.init(allocator));
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

fn finishOperation() !void {
    if (!live_preview and isGrabbed())
        try applyOperation();
    pending_operation = null;
}

fn setOperation(operation: operations.AnyOperation) !void {
    try finishOperation();
    pending_operation = operation;
    try history.add(try history.get().clone());
    try updateOperation();
}

fn selectPoint(pos: geometry.Vec2) !void {
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

fn selectRect(min_pos: geometry.Vec2, max_pos: geometry.Vec2) !void {
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
    input.onEvent(event);
    switch (event) {
        .key_press => |key| switch (key) {
            .mouse_left => if (!isGrabbed()) {
                mouse_click_pos = input.mouseCanvasPos();
            },
            else => {},
        },
        .key_release => |key| switch (key) {
            .mouse_left => if (!isGrabbed() and mouse_click_pos != null) {
                try finishOperation();

                if (!input.isShiftPressed())
                    history.get().deselectAll();

                const mouse_pos = input.mouseCanvasPos();
                if (snapping.distToPoint(mouse_pos, mouse_click_pos.?) < input.snapDist()) {
                    try selectPoint(mouse_pos);
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
                if (operations.Delete.init(history.get().*)) |op|
                    try setOperation(.{ .Delete = op });
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

pub fn draw(main_buffer: *render.Buffer, helper_buffer: *render.Buffer) !bool {
    if (!should_redraw_main and !should_redraw_helper and !should_update_transform)
        return false;
    if (should_redraw_main) {
        main_buffer.clearPaths();
        try history.get().drawing.draw(main_buffer);
        main_buffer.flushPaths();
        should_redraw_main = false;
    }
    if (should_redraw_helper) {
        helper_buffer.clearPaths();
        if (isGrabbed()) {
            try pending_operation.?.drawHelper(history.getPrev().*, helper_buffer);
        } else {
            try history.get().drawSelected(input.wideStroke(), select_color, helper_buffer);
        }
        helper_buffer.flushPaths();
        should_redraw_helper = false;
    }
    if (should_update_transform) {
        const transform = input.getTransform();
        main_buffer.setTransform(transform);
        helper_buffer.setTransform(transform);
        should_update_transform = false;
    }
    return true;
}
