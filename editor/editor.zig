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
pub var operation_is_new = false;

const live_preview = true;
pub var should_draw_canvas = true;
pub var should_draw_image = true;
pub var should_draw_helper = true;
pub var should_update_transform = true;

pub var window_size: math.Vec2 = .{ 0, 0 };
pub var canvas_pan: math.Vec2 = .{ 0, 0 };
pub var canvas_zoom: f32 = 1;
const canvas_size = math.Vec2{ 512, 512 };
const canvas_color = [4]f32{ 1, 1, 1, 1 };

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
    Order: Order,

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
        name: Image.Path.Name,

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
        enable_fill_color: bool,
        enable_stroke_color: bool,
        enable_stroke_width: bool,
        enable_stroke_cap: bool,

        pub fn init(is: ImageSelection) ?ChangeStyle {
            if (is.len() == 0) return null;
            var i: usize = 0;
            while (i < is.len()) : (i += 1) {
                if (!is.get(i).isWholePath()) return null;
            }
            const enable = is.len() == 1;
            return .{
                .style = is.get(0).path.getStyle(),
                .enable_fill_color = enable,
                .enable_stroke_color = enable,
                .enable_stroke_width = enable,
                .enable_stroke_cap = enable,
            };
        }

        pub fn apply(op: ChangeStyle, is: ImageSelection) !ImageSelection {
            var out = try is.clone();
            var i: usize = 0;
            while (i < is.len()) : (i += 1) {
                const style = &out.image.props.items(.style)[is.get(i).path.index];
                if (op.enable_fill_color) style.fill_color = op.style.fill_color;
                if (op.enable_stroke_color) style.stroke_color = op.style.stroke_color;
                if (op.enable_stroke_width) style.stroke.width = op.style.stroke.width;
                if (op.enable_stroke_cap) style.stroke.cap = op.style.stroke.cap;
            }
            return out;
        }
    };

    pub const AddPoint = struct {
        position: math.Vec2 = .{ 0, 0 },
        style: Image.Path.Style = default_style,
        name: Image.Path.Name,

        fn getDefaultName(index: usize) Image.Path.Name {
            return .{ 'P', 'a', 't', 'h', ' ', '0' + @intCast(u8, (index / 10) % 10), '0' + @intCast(u8, index % 10) } ++ .{0} ** 25;
        }

        pub fn init(is: ImageSelection) ?AddPoint {
            if (is.len() != 0) return null;
            return .{ .name = getDefaultName(is.image.len()) };
        }

        pub fn apply(op: AddPoint, is: ImageSelection) !ImageSelection {
            var out = ImageSelection{ .image = try is.image.operationAddPoint(op.position, op.style, op.name) };
            try out.selectNode(out.image.len() - 1, 0);
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
            if (snapping.snapToLooseEnd(is.image, op.position, getSnapDist())) |res| {
                if (res.index != ps.path.index)
                    return .{ .image = try is.image.operationConnectPaths(ps.path.index, ps.a == 0, res.index, res.node != 0, op.angle) };
                if (res.node != ps.a)
                    return .{ .image = try is.image.operationLoopPath(ps.path.index, op.angle) };
                return try is.clone();
            }
            var out = ImageSelection{ .image = try is.image.operationAppendPoint(ps.path.index, ps.a == 0, op.angle, op.position) };
            try out.selectNode(ps.path.index, ps.path.getNodeCount());
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
            if (is.len() != 2) return null;
            const ps0 = is.getComp(0);
            const ps1 = is.getComp(1);
            if (!ps0.isLooseEnd() or !ps1.isLooseEnd()) return null;
            return .{ ._pos_a = ps0.path.getPos(ps0.a), ._pos_b = ps1.path.getPos(ps1.a) };
        }

        pub fn apply(op: Connect, is: ImageSelection) !ImageSelection {
            const ps0 = is.getComp(0);
            const ps1 = is.getComp(1);
            if (ps0.path.index == ps1.path.index)
                return .{ .image = try is.image.operationLoopPath(ps0.path.index, if (ps0.a == 0) -op.angle else op.angle) };
            return .{ .image = try is.image.operationConnectPaths(ps0.path.index, ps0.a == 0, ps1.path.index, ps1.a != 0, op.angle) };
        }

        pub fn generateHelper(op: Connect, _: ImageSelection, gen: anytype) !void {
            try math.Arc.generate(.{
                .pos_a = op._pos_a,
                .pos_b = op._pos_b,
                .angle = op.angle,
            }, getStroke().generator(gen));
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
                try op.addUnselected(&out.image, is, if (path.isLooped()) .{ .path = path } else .{ .path = path, .b = path.getNodeCount() - 1 });
            }
            return out;
        }

        /// Adds parts of PathSelection `ps` to Image `out`, that aren't selected in ImageSelection `is`.
        fn addUnselected(op: Remove, out: *Image, is: ImageSelection, ps: ImageSelection.PathSelection) !void {
            var it = is.iterator(ps.path);
            while (it.next()) |sel_ps| {
                if (sel_ps.isLooped())
                    return;
                if (sel_ps.isSingleNode() and op.remove_single_nodes) {
                    if (ps.isLooped()) {
                        return op.addUnselected(out, is, .{ .path = ps.path, .a = ps.path.nextNode(sel_ps.b), .b = ps.path.prevNode(sel_ps.a) });
                    }
                    if (ps.containsNode(sel_ps.a)) {
                        if (sel_ps.a != ps.a) try op.addUnselected(out, is, .{ .path = ps.path, .a = ps.a, .b = ps.path.prevNode(sel_ps.a) });
                        if (sel_ps.b != ps.b) try op.addUnselected(out, is, .{ .path = ps.path, .a = ps.path.nextNode(sel_ps.b), .b = ps.b });
                        return;
                    }
                }
            }
            it = is.iterator(ps.path); // we have to do two separate iterations, because it matters if we remove single nodes first or intervals first
            while (it.next()) |sel_ps| {
                if (!sel_ps.isSingleNode()) {
                    if (ps.isLooped()) {
                        return op.addUnselected(out, is, .{ .path = ps.path, .a = sel_ps.b, .b = sel_ps.a });
                    }
                    if (ps.containsSegment(sel_ps.a)) {
                        if (sel_ps.a != ps.a) try op.addUnselected(out, is, .{ .path = ps.path, .a = ps.a, .b = sel_ps.a });
                        if (sel_ps.b != ps.b) try op.addUnselected(out, is, .{ .path = ps.path, .a = sel_ps.b, .b = ps.b });
                        return;
                    }
                }
            }
            try out.addEmptyPath(ps.path.getStyle(), ps.path.getName());
            if (ps.isLooped()) {
                try out.appendNodes(ps.path.getPositions(), ps.path.getAngles(), false);
            } else {
                var i = ps.a;
                while (i != ps.b) : (i = ps.path.nextNode(i))
                    try out.appendNode(.{ .position = ps.path.getPos(i), .angle = ps.path.getAng(i) });
                try out.appendNode(.{ .position = ps.path.getPos(i) });
            }
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
            const ps = out.getComp(0);
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

    pub const Order = struct {
        offset: isize = 0,

        pub fn init(is: ImageSelection) ?Order {
            if (is.image.len() < 2 or is.len() == 0) return null;
            var i: usize = 0;
            while (i < is.len()) : (i += 1) {
                if (!is.get(i).isWholePath()) return null;
            }
            return .{};
        }

        pub fn getLimit(is: ImageSelection) isize {
            return @intCast(isize, is.image.len() - 1);
        }

        pub fn apply(op: Order, is: ImageSelection) !ImageSelection {
            var out = ImageSelection{ .image = try Image.initCapacity(is.image.allocator, is.image.props.len, is.image.nodes.len) };
            var i: usize = 0;
            while (i < is.image.len() + std.math.absCast(op.offset)) : (i += 1) {
                if (i < is.image.len()) {
                    const selected = is.isPathSelected(i);
                    if (selected != (op.offset > 0)) {
                        out.image.addImageSlice(is.image, i, i + 1) catch unreachable;
                        if (selected) try out.selectPath(out.image.len() - 1);
                    }
                }
                if (i >= std.math.absCast(op.offset)) {
                    const j = i - std.math.absCast(op.offset);
                    const selected = is.isPathSelected(j);
                    if (selected == (op.offset > 0)) {
                        out.image.addImageSlice(is.image, j, j + 1) catch unreachable;
                        if (selected) try out.selectPath(out.image.len() - 1);
                    }
                }
            }
            return out;
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
        history.undo();
        try history.add(try op.apply(getIS()));
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
    operation_is_new = true;
    try history.add(try history.get().clone());
    try updateOperation();
}

pub fn getIS() ImageSelection {
    return history.get().*;
}

pub fn undo() void {
    history.undo();
    should_draw_image = true;
    should_draw_helper = true;
}

pub fn redo() void {
    history.redo();
    should_draw_image = true;
    should_draw_helper = true;
}

pub fn selectAll() !void {
    try history.get().selectAll();
    should_draw_helper = true;
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
    const rect = math.Rect{ .pos = .{ 0, 0 }, .radius = canvas_size / math.vec2.splat(2) };
    try rect.generate(buffer.generator(.{ canvas_color[0], canvas_color[1], canvas_color[2], 1 }));
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
