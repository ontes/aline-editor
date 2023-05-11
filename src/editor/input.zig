const std = @import("std");
const math = @import("math");
const platform = @import("platform");

const editor = @import("editor.zig");
const snapping = @import("snapping.zig");
const gui = @import("gui.zig");

var mouse_pos: math.Vec2 = .{ 0, 0 };
var prev_mouse_pos: math.Vec2 = .{ 0, 0 };

var mouse_middle_pressed: bool = false;
var ctrl_pressed: bool = false;
var shift_pressed: bool = false;
var alt_pressed: bool = false;
var mouse_click_pos: ?math.Vec2 = null;

pub fn onEvent(event: platform.Event) !void {
    switch (event) {
        .window_resize => |size| {
            editor.window_size = .{
                @intToFloat(f32, size[0]),
                @intToFloat(f32, size[1]),
            };
            editor.should_draw_helper = true;
        },
        .key_press => |key| switch (key) {
            .mouse_left => if (!gui.isMouseCaptured()) {
                mouse_click_pos = mouse_pos;
            },
            .mouse_right => if (editor.capture) |capture| {
                capture.cancel();
                editor.capture = null;
                try editor.updateOperation();
            },
            .mouse_middle => mouse_middle_pressed = true,
            .left_ctrl, .right_ctrl => ctrl_pressed = true,
            .left_shift, .right_shift => shift_pressed = true,
            .left_alt, .right_alt => alt_pressed = true,
            else => if (!gui.isKeyboardCaptured()) {
                try beginOperation(key);
            },
        },
        .key_release => |key| switch (key) {
            .mouse_left => {
                if (editor.capture) |_| {
                    editor.capture = null;
                    try editor.updateOperation();
                } else if (mouse_click_pos) |click_poss| {
                    try editor.finishOperation();
                    if (!shift_pressed)
                        editor.history.get().deselectAll();
                    if (snapping.shouldSnapToPoint(mouse_pos, click_poss, editor.getSnapDist())) {
                        try selectPoint(click_poss);
                    } else {
                        try selectRect(@min(mouse_pos, click_poss), @max(mouse_pos, click_poss));
                    }
                    editor.should_draw_helper = true;
                }
                mouse_click_pos = null;
            },
            .mouse_middle => mouse_middle_pressed = false,
            .left_ctrl, .right_ctrl => ctrl_pressed = false,
            .left_shift, .right_shift => shift_pressed = false,
            .left_alt, .right_alt => alt_pressed = false,
            else => {},
        },
        .mouse_move => |pos| {
            prev_mouse_pos = mouse_pos;
            mouse_pos = editor.canvas_pan + math.vec2.splat(editor.canvas_zoom) * math.Vec2{
                @intToFloat(f32, pos[0]) - editor.window_size[0] / 2,
                editor.window_size[1] / 2 - @intToFloat(f32, pos[1]),
            };

            if (mouse_middle_pressed) {
                editor.canvas_pan -= mouse_pos - prev_mouse_pos;
                mouse_pos = prev_mouse_pos;
            }

            if (editor.capture) |any_capture| {
                switch (any_capture) {
                    .Position => |capture| {
                        capture.pos.* = mouse_pos;
                    },
                    .Offset => |capture| {
                        capture.offset.* += (mouse_pos - prev_mouse_pos) * math.vec2.splat(if (shift_pressed) 0.1 else 1);
                    },
                    .Angle => |capture| {
                        const vec = mouse_pos - capture._origin;
                        const prev_vec = prev_mouse_pos - capture._origin;
                        capture.angle.* += std.math.atan2(f32, math.vec2.dot(vec, math.normal(prev_vec)), math.vec2.dot(vec, prev_vec)) * @as(f32, if (shift_pressed) 0.1 else 1);
                    },
                    .Scale => |capture| {
                        const vec = mouse_pos - capture._origin;
                        const prev_vec = prev_mouse_pos - capture._origin;
                        capture.scale.* *= if (capture._lock_aspect) math.vec2.splat(math.vec2.abs(vec) / math.vec2.abs(prev_vec)) else @fabs(vec / prev_vec);
                    },
                    .ArcAngle => |capture| {
                        capture.angle.* = math.Arc.angleOnPoint(.{ .pos_a = capture._pos_a, .pos_b = capture._pos_b }, mouse_pos);
                    },
                    .Shape => |capture| {
                        if (mouse_click_pos) |click_pos| {
                            capture.pos.* = click_pos;
                            capture.radius.* = if (capture._lock_aspect) math.vec2.splat(@reduce(.Min, @fabs(click_pos - mouse_pos))) else @fabs(click_pos - mouse_pos);
                        } else {
                            capture.pos.* = mouse_pos;
                        }
                    },
                }
                try editor.updateOperation();
            }
        },
        .mouse_scroll => |offset| {
            editor.canvas_zoom *= std.math.pow(f32, 0.8, @intToFloat(f32, offset));
            editor.should_draw_helper = true;
        },
        .window_close => editor.should_run = false,
        else => {},
    }
}

fn beginOperation(key: platform.Key) !void {
    try editor.finishOperation();
    switch (key) {
        .tab => if (editor.Operation.ChangeStyle.init(editor.getIS())) |op| {
            try editor.setOperation(.{ .ChangeStyle = op });
        },
        .f2 => if (editor.Operation.Rename.init(editor.getIS())) |op| {
            try editor.setOperation(.{ .Rename = op });
        },
        .a => if (ctrl_pressed) {
            try editor.selectAll();
        } else if (editor.Operation.AddPoint.init(editor.getIS())) |op| {
            try editor.setOperation(.{ .AddPoint = op });
            editor.capture = .{ .Position = editor.Capture.Position.init(&editor.operation.?.AddPoint.position) };
        } else if (editor.Operation.Append.init(editor.getIS())) |op| {
            try editor.setOperation(.{ .Append = op });
            editor.capture = .{ .Position = editor.Capture.Position.init(&editor.operation.?.Append.position) };
        },
        .c => if (editor.Operation.Connect.init(editor.getIS())) |op| {
            try editor.setOperation(.{ .Connect = op });
        },
        .g => if (editor.Operation.Move.init(editor.getIS())) |op| {
            try editor.setOperation(.{ .Move = op });
            editor.capture = .{ .Offset = editor.Capture.Offset.init(&editor.operation.?.Move.offset) };
        },
        .r => if (editor.Operation.Rotate.init(editor.getIS())) |op| {
            try editor.setOperation(.{ .Rotate = op });
            editor.capture = .{ .Angle = editor.Capture.Angle.init(&editor.operation.?.Rotate.angle, op.origin) };
        },
        .s => if (editor.Operation.Scale.init(editor.getIS())) |op| {
            try editor.setOperation(.{ .Scale = op });
            editor.capture = .{ .Scale = editor.Capture.Scale.init(&editor.operation.?.Scale.scale, op.origin, op.lock_aspect) };
        },
        .d => if (editor.Operation.ChangeAngle.init(editor.getIS())) |op| {
            try editor.setOperation(.{ .ChangeAngle = op });
            editor.capture = .{ .ArcAngle = editor.Capture.ArcAngle.init(&editor.operation.?.ChangeAngle.angle, editor.operation.?.ChangeAngle._pos_a, editor.operation.?.ChangeAngle._pos_b) };
        },
        .delete => if (editor.Operation.Remove.init(editor.getIS())) |op| {
            try editor.setOperation(.{ .Remove = op });
        },
        .up => if (editor.Operation.Order.init(editor.getIS())) |op_| {
            var op = op_;
            op.offset = if (shift_pressed) editor.Operation.Order.getLimit(editor.getIS()) else 1;
            try editor.setOperation(.{ .Order = op });
        },
        .down => if (editor.Operation.Order.init(editor.getIS())) |op_| {
            var op = op_;
            op.offset = if (shift_pressed) -editor.Operation.Order.getLimit(editor.getIS()) else -1;
            try editor.setOperation(.{ .Order = op });
        },
        .z => if (ctrl_pressed and editor.history.canUndo()) {
            editor.undo();
        },
        .y => if (ctrl_pressed and editor.history.canRedo()) {
            editor.redo();
        },
        else => {},
    }
}

fn selectPoint(pos: math.Vec2) !void {
    const is = editor.history.get();
    if (snapping.select(is.image, pos, editor.getSnapDist())) |s| {
        if (ctrl_pressed) {
            try is.togglePath(s.index);
        } else switch (s.val) {
            .node => |node| try is.toggleNode(s.index, node),
            .segment => |segment| try is.toggleSegment(s.index, segment),
            .loop => try is.togglePath(s.index),
        }
    }
}

fn selectRect(min_pos: math.Vec2, max_pos: math.Vec2) !void {
    const is = editor.history.get();
    var it = is.image.iterator();
    while (it.next()) |path| {
        var i: usize = 0;
        while (i < path.getNodeCount()) : (i += 1) {
            if (@reduce(.And, path.getPos(i) >= min_pos) and
                @reduce(.And, path.getPos(i) <= max_pos) and
                !is.isNodeSelected(path.index, i))
                try is.selectNode(path.index, i);
        }
        i = 0;
        while (i < path.getSegmentCount()) : (i += 1) {
            const arc = path.getArc(i);
            const arc_bounds = arc.boundingBox();
            if (@reduce(.And, arc_bounds[0] >= min_pos) and
                @reduce(.And, arc_bounds[1] <= max_pos) and
                !is.isSegmentSelected(path.index, i))
                try is.selectSegment(path.index, i);
        }
    }
}
