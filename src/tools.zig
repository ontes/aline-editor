const std = @import("std");
const geometry = @import("geometry.zig");
const render = @import("render.zig");
const canvas = @import("canvas.zig");
const history = @import("history.zig");
const vec2 = @import("linalg.zig").vec(2, f32);
const edit = @import("edit.zig");

const preview_color = [4]u8{ 255, 32, 32, 255 };
const preview_stroke = geometry.Stroke{ .width = 0.005, .cap = .round };

const select_color = [4]u8{ 255, 255, 0, 128 };
const select_stroke = geometry.Stroke{ .width = 0.015, .cap = .round };

pub var tool_buffer: render.Buffer = undefined;

const Tool = enum {
    select,
    append,
    move,
    change_angle,
    split_segment,

    fn namespace(comptime md: Tool) type {
        return switch (md) {
            .select => select,
            .append => append,
            .move => move,
            .change_angle => change_angle,
            .split_segment => split_segment,
        };
    }

    fn canInit(m: Tool) bool {
        switch (m) {
            inline else => |cm| return cm.namespace().canInit(),
        }
    }
    fn init(m: Tool) !void {
        switch (m) {
            inline else => |cm| try cm.namespace().init(),
        }
    }
    fn deinit(m: Tool) void {
        switch (m) {
            inline else => |cm| cm.namespace().deinit(),
        }
    }
    fn onMouseMove(m: Tool) !void {
        switch (m) {
            inline else => |cm| try cm.namespace().onMouseMove(),
        }
    }

    fn onMousePress(m: Tool) !void {
        switch (m) {
            inline else => |cm| try cm.namespace().onMousePress(),
        }
    }

    fn onMouseRelease(m: Tool) !void {
        switch (m) {
            inline else => |cm| try cm.namespace().onMouseRelease(),
        }
    }
};
var current_tool: Tool = .select;

pub fn setTool(tool: Tool) !bool {
    if (!tool.canInit())
        return false;
    current_tool.deinit();
    current_tool = tool;
    try current_tool.init();
    return true;
}

pub fn reset() void {
    edit.clear();
    _ = setTool(.select) catch unreachable;
}

pub fn init(allocator: std.mem.Allocator, context: render.Context) void {
    edit.init(allocator);
    tool_buffer = render.Buffer.init(context, allocator);
}

pub fn deinit() void {
    edit.deinit();
    tool_buffer.deinit();
}

pub var mouse_pos = [2]f32{ 0, 0 };
pub var shift_pressed = false;

pub fn onMouseMove(pos: [2]f32) !void {
    mouse_pos = pos;
    try current_tool.onMouseMove();
}

pub fn onMousePress() !void {
    try current_tool.onMousePress();
}

pub fn onMouseRelease() !void {
    try current_tool.onMouseRelease();
}

pub fn onShiftPress() void {
    shift_pressed = true;
}

pub fn onShiftRelease() void {
    shift_pressed = false;
}

pub fn delete() !void {
    if (edit.delete.can()) {
        try edit.delete.do();
        reset();
        try history.step();
    }
}

pub fn connect() !void {
    if (edit.connect.can()) {
        try edit.connect.do();
        _ = setTool(.select) catch unreachable;
        try history.step();
    }
}

const select = struct {
    pub inline fn canInit() bool {
        return true;
    }
    pub inline fn init() !void {
        try updateToolBuffer();
    }
    pub inline fn deinit() void {}

    fn updateToolBuffer() !void {
        tool_buffer.clear();
        try edit.gen(select_stroke, select_color, &tool_buffer);
        tool_buffer.flush();
    }

    fn onMouseMove() !void {}

    fn onMousePress() !void {
        if (!shift_pressed)
            edit.clear();
        var i: u32 = 0;
        while (i < canvas.objects.items.len) : (i += 1) {
            const object_index = @intCast(u32, canvas.objects.items.len - i - 1);
            const path = canvas.objects.items[object_index].toPath();
            if (selectedNode(path, mouse_pos, 0.05)) |index| {
                try edit.toggleNode(object_index, index);
            } else if (selectedSegment(path, mouse_pos, 0.1)) |index| {
                try edit.toggleSegment(object_index, index);
            } else if (path.isLooped() and path.containsPoint(mouse_pos)) {
                try edit.toggleLoop(object_index);
            }
        }
        try updateToolBuffer();
    }

    fn onMouseRelease() !void {}

    fn selectedNode(path: geometry.Path, pos: geometry.Vec2, max_diff: f32) ?u32 {
        var index: u32 = 0;
        while (index < path.len()) : (index += 1) {
            if (vec2.norm(pos - path.positions[index]) < max_diff * max_diff)
                return index;
        }
        return null;
    }

    fn selectedSegment(path: geometry.Path, pos: geometry.Vec2, max_diff: f32) ?u32 {
        var index: u32 = 0;
        while (index < path.angles.len) : (index += 1) {
            const arc = path.getArc(index);
            if (@fabs(@tan(arc.angleOnPoint(pos) / 2) - @tan(arc.angle / 2)) < max_diff)
                return index;
        }
        return null;
    }
};

const move = struct {
    var start_pos: geometry.Vec2 = undefined;

    inline fn getOffset() geometry.Vec2 {
        return mouse_pos - start_pos;
    }

    pub fn canInit() bool {
        return edit.move.can();
    }

    pub fn init() !void {
        start_pos = mouse_pos;
        try updateToolBuffer();
    }

    pub fn deinit() void {
        start_pos = undefined;
    }

    fn updateToolBuffer() !void {
        tool_buffer.clear();
        try edit.move.gen(getOffset(), preview_stroke, preview_color, &tool_buffer);
        tool_buffer.flush();
    }

    fn onMouseMove() !void {
        try updateToolBuffer();
    }

    fn onMousePress() !void {}

    fn onMouseRelease() !void {
        try edit.move.do(getOffset());
        _ = try setTool(.select);
        try history.step();
    }
};

const append = struct {
    fn canInit() bool {
        return edit.add_point.can() or edit.append.can();
    }

    fn init() !void {
        if (edit.add_point.can())
            try edit.add_point.do(mouse_pos);
        try updateToolBuffer();
    }

    fn deinit() void {}

    fn updateToolBuffer() !void {
        tool_buffer.clear();
        try edit.append.gen(mouse_pos, preview_stroke, preview_color, &tool_buffer);
        tool_buffer.flush();
    }

    fn onMouseMove() !void {
        try updateToolBuffer();
    }

    fn onMousePress() !void {}

    fn onMouseRelease() !void {
        // const interval = edit.intervals.items[0];
        // if (vec2.norm(mouse_pos - interval.getPath().positions[0]) < 0.05 * 0.05) { // ending by creating a loop
        //     try edit.append_loop.do();
        //     _ = try setTool(.select);
        // } else {
        try edit.append.do(mouse_pos);
        // }
        try history.step();
    }
};

const change_angle = struct {
    inline fn getAngle() f32 {
        const interval = edit.intervals.items[0];
        return interval.getPath().getArc(interval.a).angleOnPoint(mouse_pos);
    }

    fn canInit() bool {
        return edit.change_angle.can();
    }

    fn init() !void {
        try updateToolBuffer();
    }

    fn deinit() void {}

    fn updateToolBuffer() !void {
        tool_buffer.clear();
        try edit.change_angle.gen(getAngle(), preview_stroke, preview_color, &tool_buffer);
        tool_buffer.flush();
    }

    fn onMouseMove() !void {
        try updateToolBuffer();
    }

    fn onMousePress() !void {}

    fn onMouseRelease() !void {
        try edit.change_angle.do(getAngle());
        _ = try setTool(.select);
        try history.step();
    }
};

const split_segment = struct {
    inline fn getParam() f32 {
        const interval = edit.intervals.items[0];
        const arc = interval.getPath().getArc(interval.a);
        if (arc.angle == 0) {
            return geometry.linesIntersection(arc.pos_a, arc.pos_b - arc.pos_a, mouse_pos, geometry.normal(arc.pos_b - arc.pos_a));
        } else {
            const center = arc.toCircle().pos;
            return geometry.angleBetween(mouse_pos - center, arc.pos_a - center) / 2 / arc.angle;
        }
    }

    fn canInit() bool {
        return edit.split_segment.can();
    }

    fn init() !void {
        try updateToolBuffer();
    }

    fn deinit() void {}

    fn updateToolBuffer() !void {
        tool_buffer.clear();
        try edit.split_segment.gen(getParam(), preview_stroke, preview_color, &tool_buffer);
        tool_buffer.flush();
    }

    fn onMouseMove() !void {
        try updateToolBuffer();
    }

    fn onMousePress() !void {}

    fn onMouseRelease() !void {
        try edit.split_segment.do(getParam());
        _ = try setTool(.select);
        try history.step();
    }
};
