const std = @import("std");
const math = @import("math");
const render = @import("render");

const Image = @import("Image.zig");
const ImageSelection = @import("ImageSelection.zig");
const History = @import("History.zig");
const snapping = @import("snapping.zig");

pub var history: History = undefined;
pub var operation: ?Operation = null;
pub var capture: ?Capture = null;
pub var operation_in_new = false;

const live_preview = true;
pub var should_draw_canvas = true;
pub var should_draw_image = true;
pub var should_draw_helper = true;
pub var should_update_transform = true;

pub var window_size: math.Vec2 = .{ 0, 0 };
pub var canvas_pan: math.Vec2 = .{ 0, 0 };
pub var canvas_zoom: f32 = 1;
const canvas_size = math.Vec2{ 512, 512 };
const canvas_corner_radius: f32 = 16;

const default_style = Image.Path.Style{
    .stroke = .{ .width = 2, .cap = .round },
    .fill_color = .{ 0.5, 0.5, 0.5, 1 },
    .stroke_color = .{ 0, 0, 0, 1 },
};

pub const Operation = union(enum) {
    Rename: Rename,
    ChangeStyle: ChangeStyle,
    AddPoint: AddPoint,
    Append: Append,
    Connect: Connect,
    Move: Move,
    Remove: Remove,
    ChangeAngle: ChangeAngle,

    pub fn apply(op: Operation, is: ImageSelection) !ImageSelection {
        return switch (op) {
            inline else => |comptime_op| comptime_op.apply(is),
        };
    }

    pub fn generateHelper(op: Operation, is: ImageSelection, gen: anytype) !void {
        return switch (op) {
            inline else => |comptime_op| if (@hasDecl(@TypeOf(comptime_op), "generateHelper")) comptime_op.generateHelper(is, gen),
        };
    }

    pub const Rename = struct {
        name: [16]u8,

        pub fn init(is: ImageSelection) ?Rename {
            if (is.len() != 1) return null;
            const ps = is.get(0);
            if (!ps.isWholePath()) return null;
            return .{ .name = ps.path.getName() };
        }

        pub fn apply(op: Rename, is: ImageSelection) !ImageSelection {
            const ps = is.get(0);
            var out = try is.clone();
            out.image.props.items(.name)[ps.path.index] = op.name;
            return out;
        }
    };

    pub const ChangeStyle = struct {
        style: Image.Path.Style,

        pub fn init(is: ImageSelection) ?ChangeStyle {
            if (is.len() != 1) return null;
            const ps = is.get(0);
            if (!ps.isWholePath()) return null;
            return .{ .style = ps.path.getStyle() };
        }

        pub fn apply(op: ChangeStyle, is: ImageSelection) !ImageSelection {
            const ps = is.get(0);
            var out = try is.clone();
            out.image.props.items(.style)[ps.path.index] = op.style;
            return out;
        }
    };

    pub const AddPoint = struct {
        position: math.Vec2 = .{ 0, 0 },
        style: Image.Path.Style = default_style,
        name: Image.Path.Name = .{ 'u', 'n', 'n', 'a', 'm', 'e', 'd' } ++ .{0} ** 9,

        pub fn init(is: ImageSelection) ?AddPoint {
            if (is.len() != 0) return null;
            return .{};
        }

        pub fn apply(op: AddPoint, is: ImageSelection) !ImageSelection {
            var out = try is.cloneWithNothingSelected();
            try out.image.addPoint(op.position, op.style, op.name);
            try out.selectNode(is.image.len(), 0);
            return out;
        }

        pub fn generateHelper(op: AddPoint, _: ImageSelection, gen: anytype) !void {
            var pass = getWideStroke().generator(gen).begin();
            try pass.add(op.position, std.math.nan_f32);
            try pass.end();
        }
    };

    pub const Append = struct {
        position: math.Vec2,
        angle: f32 = 0,
        _pos_a: math.Vec2,

        pub fn init(is: ImageSelection) ?Append {
            if (is.len() != 1) return null;
            const ps = is.getComp(0);
            if (!ps.isLooseEnd()) return null;
            const pos_a = ps.path.getPos(ps.a);
            return .{ ._pos_a = pos_a, .position = pos_a };
        }

        pub fn apply(op: Append, is: ImageSelection) !ImageSelection {
            const ps = is.getComp(0);
            var out = try is.cloneWithNothingSelected();
            if (ps.a == 0)
                ps.path.reverse();
            if (snapping.snapToLooseEnd(is.image, op.position, getSnapDist())) |res| {
                if (res.index == ps.path.index) {
                    if (res.node != ps.a)
                        out.image.loopPath(ps.path.index, op.angle);
                } else {
                    if (res.node != 0)
                        out.image.getComp(res.index).reverse();
                    _ = out.image.joinPaths(ps.path.index, res.index, op.angle);
                }
            } else {
                try out.image.appendPoint(ps.path.index, op.position, op.angle);
                try out.selectNode(ps.path.index, ps.path.getNodeCount());
            }
            return out;
        }

        pub fn generateHelper(op: Append, is: ImageSelection, gen: anytype) !void {
            const ps = is.getComp(0);

            try math.Arc.generate(.{
                .pos_a = ps.path.getPos(ps.a),
                .pos_b = if (snapping.snapToLooseEnd(is.image, op.position, getSnapDist())) |res| is.image.get(res.index).getPos(res.node) else op.position,
                .angle = op.angle,
            }, getStroke().generator(gen));
        }
    };

    pub const Connect = struct {
        angle: f32 = 0,
        _pos_a: math.Vec2,
        _pos_b: math.Vec2,

        pub fn init(is: ImageSelection) ?Connect {
            if (is.len() != 0) return null;
            const ps_a = is.getComp(0);
            const ps_b = is.getComp(1);
            if (!ps_a.isLooseEnd() or !ps_b.isLooseEnd()) return null;
            return .{ ._pos_a = ps_a.path.getPos(ps_a.a), ._pos_b = ps_b.path.getPos(ps_b.a) };
        }

        pub fn apply(op: Connect, is: ImageSelection) !ImageSelection {
            const ps_a = is.getComp(0);
            const ps_b = is.getComp(1);
            var out = try is.cloneWithNothingSelected();
            if (ps_a.a == 0) ps_a.path.reverse();
            if (ps_b.a != 0) ps_b.path.reverse();
            const node = ps_a.path.getNodeCount() - 1;
            const index = out.image.joinPaths(ps_a.path.index, ps_b.path.index, op.angle);
            try out.selectSegment(index, node);
            return out;
        }
    };

    pub const Move = struct {
        offset: math.Vec2 = .{ 0, 0 },

        pub fn init(is: ImageSelection) ?Move {
            if (is.len() == 0) return null;
            return .{};
        }

        fn getMat(op: Move) math.Mat3 {
            return math.mat3.translate(op.offset);
        }

        pub fn apply(op: Move, is: ImageSelection) !ImageSelection {
            var out = try is.clone();
            out.transformSelected(op.getMat());
            return out;
        }

        pub fn generateHelper(op: Move, is: ImageSelection, gen: anytype) !void {
            try is.generateSelected(math.transformGenerator(op.getMat(), getWideStroke().generator(gen)));
            try is.generateTransformEdges(op.getMat(), getStroke().generator(gen));
        }
    };

    pub const Remove = struct {
        remove_single_nodes: bool = true,

        pub fn init(is: ImageSelection) ?Remove {
            if (is.len() == 0) return null;
            return .{};
        }

        pub fn apply(op: Remove, is: ImageSelection) !ImageSelection {
            var out = ImageSelection.init(is.image.allocator);
            var it = is.image.iterator();
            while (it.next()) |path| {
                if (path.isLooped()) {
                    try op.addUnselectedLoop(&out.image, is, path.index);
                } else {
                    try op.addUnselectedInterval(&out.image, is, path.index, 0, path.getNodeCount() - 1);
                }
            }
            return out;
        }

        fn addUnselectedLoop(op: Remove, out: *Image, is: ImageSelection, path_index: usize) !void {
            const path = is.image.getComp(path_index);
            var it = is.iterator(path);
            while (it.next()) |ps| {
                if (ps.isLooped()) continue;
                if (!ps.isSingleNode()) {
                    try op.addUnselectedInterval(out, is, path_index, ps.b, ps.a);
                    return;
                }
                if (ps.isSingleNode() and op.remove_single_nodes) {
                    try op.addUnselectedInterval(out, is, path_index, path.nextNode(ps.b), path.prevNode(ps.a));
                    return;
                }
            }
            try out.addPoint(path.getPos(0), path.getStyle(), path.getName());
            const new_index = out.len() - 1;
            var i: usize = 0;
            while (i + 1 < path.getNodeCount()) : (i += 1)
                try out.appendPoint(new_index, path.getPos(i + 1), path.getAng(i));
            out.loopPath(new_index, path.getAng(i));
        }

        fn addUnselectedInterval(op: Remove, out: *Image, is: ImageSelection, path_index: usize, a: usize, b: usize) !void {
            const path = is.image.getComp(path_index);
            var it = is.iterator(path);
            while (it.next()) |ps| {
                if (ps.isLooped()) continue;
                if (!ps.isSingleNode() and ImageSelection.PathSelection.containsSegment(.{ .a = a, .b = b, .path = path }, ps.a)) {
                    if (ps.a != a)
                        try op.addUnselectedInterval(out, is, path_index, a, ps.a);
                    if (ps.b != b)
                        try op.addUnselectedInterval(out, is, path_index, ps.b, b);
                    return;
                }
                if (ps.isSingleNode() and op.remove_single_nodes and ps.containsNode(ps.a)) {
                    if (ps.a != a)
                        try op.addUnselectedInterval(out, is, path_index, a, path.prevNode(ps.a));
                    if (ps.b != b)
                        try op.addUnselectedInterval(out, is, path_index, path.nextNode(ps.b), b);
                    return;
                }
                if (ps.isSingleNode() and ps.containsNode(a))
                    return;
            }
            try out.addPoint(path.getPos(a), path.getStyle(), path.getName());
            const new_index = out.len() - 1;
            var i = a;
            while (i != b) : (i = path.nextNode(i))
                try out.appendPoint(new_index, path.getPos(path.nextNode(i)), path.getAng(i));
        }
    };

    pub const ChangeAngle = struct {
        angle: f32,
        _pos_a: math.Vec2, // helpers
        _pos_b: math.Vec2,

        pub fn init(is: ImageSelection) ?ChangeAngle {
            if (is.len() != 1) return null;
            const ps = is.getComp(0);
            if (!ps.isSingleSegment()) return null;
            const arc = ps.path.getArc(ps.a);
            return .{ .angle = arc.angle, ._pos_a = arc.pos_a, ._pos_b = arc.pos_b };
        }

        pub fn apply(op: ChangeAngle, is: ImageSelection) !ImageSelection {
            var out = try is.clone();
            const ps = is.getComp(0);
            ps.path.getAngles()[ps.a] = op.angle;
            return out;
        }

        pub fn generateHelper(op: ChangeAngle, is: ImageSelection, gen: anytype) !void {
            const ps = is.getComp(0);
            var arc = ps.path.getArc(ps.a);
            arc.angle = op.angle;
            try arc.generate(getStroke().generator(gen));
        }
    };
};

pub const Capture = union(enum) {
    Position: Position,
    Offset: Offset,
    Angle: Angle,

    pub fn cancel(any_capture: Capture) void {
        return switch (any_capture) {
            inline else => |comptime_capture| comptime_capture.cancel(),
        };
    }

    pub const Position = struct {
        pos: *math.Vec2,
        orig_pos: math.Vec2,

        pub fn init(pos: *math.Vec2) Position {
            return .{ .pos = pos, .orig_pos = pos.* };
        }

        pub fn cancel(cap: Position) void {
            cap.pos.* = cap.orig_pos;
        }
    };

    pub const Offset = struct {
        offset: *math.Vec2,
        orig_offset: math.Vec2,

        pub fn init(offset: *math.Vec2) Offset {
            return .{ .offset = offset, .orig_offset = offset.* };
        }

        pub fn cancel(cap: Offset) void {
            cap.offset.* = cap.orig_offset;
        }
    };

    pub const Angle = struct {
        angle: *f32,
        orig_angle: f32,
        pos_a: math.Vec2,
        pos_b: math.Vec2,

        pub fn init(angle: *f32, pos_a: math.Vec2, pos_b: math.Vec2) Angle {
            return .{ .angle = angle, .orig_angle = angle.*, .pos_a = pos_a, .pos_b = pos_b };
        }

        pub fn cancel(cap: Angle) void {
            cap.angle.* = cap.orig_angle;
        }
    };
};

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
    if (capture == null or live_preview)
        try applyOperation();
    should_draw_helper = true;
}

pub fn finishOperation() !void {
    if (capture != null and !live_preview)
        try applyOperation();
    operation = null;
    capture = null;
    should_draw_helper = true;
}

pub fn setOperation(new_operation: Operation) !void {
    try finishOperation();
    operation = new_operation;
    operation_in_new = true;
    try history.add(try history.get().clone());
    try updateOperation();
}

const select_color = [4]f32{ 0.9, 0.9, 0, 1 };
const preview_color = [4]f32{ 0.9, 0, 0, 1 };

pub fn drawImage(buffer: *render.Buffer) !void {
    try history.get().image.draw(buffer);
}

pub fn drawHelper(buffer: *render.Buffer) !void {
    if (capture != null) {
        try operation.?.generateHelper(history.getPrev().*, buffer.generator(preview_color));
    } else {
        try history.get().generateSelected(getWideStroke().generator(buffer.generator(select_color)));
    }
}

pub fn drawCanvas(buffer: *render.Buffer) !void {
    const rect = math.RoundedRect{
        .pos = .{ 0, 0 },
        .radius = canvas_size / math.vec2.splat(2),
        .corner_radius = canvas_corner_radius,
    };
    try rect.generate(buffer.generator(.{ 255, 255, 255, 255 }));
}

pub fn getTransform() math.Mat3 {
    const scale = math.vec2.splat(2 / canvas_zoom) / window_size;
    return math.mat3.mult(math.mat3.scale(.{ scale[0], scale[1], 1 }), math.mat3.translate(-canvas_pan));
}

pub fn getSnapDist() f32 {
    return 10 * canvas_zoom;
}

fn getStroke() math.Stroke {
    return .{ .width = 2 * canvas_zoom, .cap = .round };
}
fn getWideStroke() math.Stroke {
    return .{ .width = 4 * canvas_zoom, .cap = .round };
}
