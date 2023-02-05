const math = @import("math");
const platform = @import("platform");

const canvas = @import("canvas.zig");
const editor = @import("editor.zig");
const operations = @import("operations.zig");
const grabs = @import("grabs.zig");
const snapping = @import("snapping.zig");
const gui = @import("gui.zig");

pub var ctrl_pressed: bool = false;
pub var shift_pressed: bool = false;
pub var alt_pressed: bool = false;
var mouse_click_pos: ?math.Vec2 = null;

pub fn onEvent(event: platform.Event) !void {
    switch (event) {
        .key_press => |key| switch (key) {
            .mouse_left => if (editor.grab) |_| {
                editor.grab = null;
                try editor.updateOperation();
            } else if (!gui.isMouseGrabbed()) {
                mouse_click_pos = canvas.mousePos();
            },
            .mouse_right => if (editor.grab) |grab| {
                grab.cancel();
                editor.grab = null;
                try editor.updateOperation();
            },
            .left_ctrl, .right_ctrl => ctrl_pressed = true,
            .left_shift, .right_shift => shift_pressed = true,
            .left_alt, .right_alt => alt_pressed = true,
            else => if (!gui.isKeyboardGrabbed()) {
                try beginOperation(key);
            },
        },
        .key_release => |key| switch (key) {
            .mouse_left => {
                if (mouse_click_pos != null) {
                    if (editor.grab == null and !gui.isMouseGrabbed()) {
                        try editor.finishOperation();
                        if (!shift_pressed)
                            editor.history.get().deselectAll();
                        const mouse_pos = canvas.mousePos();
                        if (snapping.shouldSnapToPoint(mouse_pos, mouse_click_pos.?)) {
                            try selectPoint(mouse_click_pos.?);
                        } else {
                            try selectRect(@min(mouse_pos, mouse_click_pos.?), @max(mouse_pos, mouse_click_pos.?));
                        }
                        editor.should_draw_helper = true;
                    }
                    mouse_click_pos = null;
                }
            },
            .left_ctrl, .right_ctrl => ctrl_pressed = false,
            .left_shift, .right_shift => shift_pressed = false,
            .left_alt, .right_alt => alt_pressed = false,
            else => {},
        },
        else => {},
    }
}

fn beginOperation(key: platform.Key) !void {
    try editor.finishOperation();
    switch (key) {
        .tab => if (operations.ChangeStyle.init(editor.history.get().*)) |op| {
            try editor.setOperation(.{ .ChangeStyle = op });
        },
        .f2 => if (operations.Rename.init(editor.history.get().*)) |op| {
            try editor.setOperation(.{ .Rename = op });
        },
        .a => if (ctrl_pressed) {
            try editor.history.get().selectAll();
            editor.should_draw_helper = true;
        } else if (operations.AddPoint.init(editor.history.get().*)) |op| {
            try editor.setOperation(.{ .AddPoint = op });
            editor.grab = .{ .Position = grabs.Position.init(&editor.operation.?.AddPoint.position) };
        } else if (operations.Append.init(editor.history.get().*)) |op| {
            try editor.setOperation(.{ .Append = op });
            editor.grab = .{ .Position = grabs.Position.init(&editor.operation.?.Append.position) };
        },
        .c => if (operations.Connect.init(editor.history.get().*)) |op| {
            try editor.setOperation(.{ .Connect = op });
        },
        .g => if (operations.Move.init(editor.history.get().*)) |op| {
            try editor.setOperation(.{ .Move = op });
            editor.grab = .{ .Offset = grabs.Offset.init(&editor.operation.?.Move.offset) };
        },
        .d => if (operations.ChangeAngle.init(editor.history.get().*)) |op| {
            try editor.setOperation(.{ .ChangeAngle = op });
            editor.grab = .{ .Angle = grabs.Angle.init(&editor.operation.?.ChangeAngle.angle, editor.operation.?.ChangeAngle._pos_a, editor.operation.?.ChangeAngle._pos_b) };
        },
        .delete => if (operations.Remove.init(editor.history.get().*)) |op| {
            try editor.setOperation(.{ .Remove = op });
        },
        .z => if (ctrl_pressed and editor.history.undo()) {
            editor.should_draw_image = true;
            editor.should_draw_helper = true;
        },
        .y => if (ctrl_pressed and editor.history.redo()) {
            editor.should_draw_image = true;
            editor.should_draw_helper = true;
        },
        else => {},
    }
}

fn selectPoint(pos: math.Vec2) !void {
    const sel = editor.history.get();
    if (snapping.select(sel.image, pos)) |s| {
        if (ctrl_pressed) {
            try sel.togglePath(s.index);
        } else switch (s.val) {
            .node => |node| try sel.toggleNode(s.index, node),
            .segment => |segment| try sel.toggleSegment(s.index, segment),
            .loop => try sel.togglePath(s.index),
        }
    }
}

fn selectRect(min_pos: math.Vec2, max_pos: math.Vec2) !void {
    const sel = editor.history.get();
    var it = sel.image.pathIterator();
    while (it.next()) |path| {
        var i: u32 = 0;
        while (i < path.len()) : (i += 1) {
            if (@reduce(.And, path.positions[i] >= min_pos) and
                @reduce(.And, path.positions[i] <= max_pos) and
                !sel.isNodeSelected(it.getIndex(), i))
                try sel.selectNode(it.getIndex(), i);
        }
        i = 0;
        while (i < path.angles.len) : (i += 1) {
            const arc = path.getArc(i);
            const arc_bounds = arc.boundingBox();
            if (@reduce(.And, arc_bounds[0] >= min_pos) and
                @reduce(.And, arc_bounds[1] <= max_pos) and
                !sel.isSegmentSelected(it.getIndex(), i))
                try sel.selectSegment(it.getIndex(), i);
        }
    }
}
