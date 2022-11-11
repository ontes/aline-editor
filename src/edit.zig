const std = @import("std");
const geometry = @import("geometry.zig");
const render = @import("render.zig");
const canvas = @import("canvas.zig");
const vec2 = @import("linalg.zig").vec(2, f32);

pub const Interval = struct {
    object_index: u32,
    a: u32,
    b: u32,

    pub fn getObject(interval: Interval) *canvas.Object {
        return &canvas.objects.items[interval.object_index];
    }

    pub fn getPath(interval: Interval) geometry.Path {
        return interval.getObject().toPath();
    }

    fn containsNode(interval: Interval, index: u32) bool {
        const a = index >= interval.a;
        const b = index <= interval.b;
        return if (interval.a <= interval.b) a and b else a or b;
    }

    fn containsSegment(interval: Interval, index: u32) bool {
        const a = index >= interval.a;
        const b = index < interval.b;
        return if (interval.a <= interval.b) a and b else a or b;
    }

    fn isSingleNode(interval: Interval) bool {
        return interval.a == interval.b;
    }

    fn isSingleSegment(interval: Interval) bool {
        return interval.getPath().nextIndex(interval.a) == interval.b;
    }

    fn isLooseEnd(interval: Interval) bool {
        return interval.isSingleNode() and !interval.getPath().isLooped() and
            (interval.a == 0 or interval.a == interval.getPath().len() - 1);
    }
};

pub const Loop = struct {
    object_index: u32,

    pub fn getObject(loop: Loop) *canvas.Object {
        return &canvas.objects.items[loop.object_index];
    }

    pub fn getPath(loop: Loop) geometry.Path {
        return loop.getObject().toPath();
    }
};

pub var intervals: std.ArrayList(Interval) = undefined;
pub var loops: std.ArrayList(Loop) = undefined;

pub fn init(allocator: std.mem.Allocator) void {
    intervals = std.ArrayList(Interval).init(allocator);
    loops = std.ArrayList(Loop).init(allocator);
}

pub fn deinit() void {
    intervals.deinit();
    loops.deinit();
}

pub fn clear() void {
    intervals.clearRetainingCapacity();
    loops.clearRetainingCapacity();
}

pub fn toggleNode(object_index: u32, index: u32) !void {
    const path = canvas.objects.items[object_index].toPath();
    var i: usize = loops.items.len;
    while (i > 0) : (i -= 1) {
        const loop = loops.items[i - 1];
        if (loop.object_index == object_index) {
            _ = loops.swapRemove(i - 1);
            try intervals.append(.{
                .object_index = object_index,
                .a = path.nextIndex(index),
                .b = path.prevIndex(index),
            });
            return;
        }
    }
    i = intervals.items.len;
    while (i > 0) : (i -= 1) {
        const interval = intervals.items[i - 1];
        if (interval.object_index == object_index and interval.containsNode(index)) {
            _ = intervals.swapRemove(i - 1);
            if (interval.a != index) {
                try intervals.append(.{
                    .object_index = object_index,
                    .a = interval.a,
                    .b = path.prevIndex(index),
                });
            }
            if (interval.b != index) {
                try intervals.append(.{
                    .object_index = object_index,
                    .a = path.nextIndex(index),
                    .b = interval.b,
                });
            }
            return;
        }
    }
    try intervals.append(.{
        .object_index = object_index,
        .a = index,
        .b = index,
    });
}

pub fn toggleSegment(object_index: u32, index: u32) !void {
    const path = canvas.objects.items[object_index].toPath();
    var i: usize = loops.items.len;
    while (i > 0) : (i -= 1) {
        const loop = loops.items[i - 1];
        if (loop.object_index == object_index) {
            _ = loops.swapRemove(i - 1);
            try intervals.append(.{
                .object_index = object_index,
                .a = path.nextIndex(index),
                .b = index,
            });
            return;
        }
    }
    var a = index;
    var b = path.nextIndex(index);
    i = intervals.items.len;
    while (i > 0) : (i -= 1) {
        const interval = intervals.items[i - 1];
        if (interval.object_index == object_index) {
            if (interval.containsSegment(index)) {
                _ = intervals.swapRemove(i - 1);
                if (interval.a != index) {
                    try intervals.append(.{
                        .object_index = object_index,
                        .a = interval.a,
                        .b = index,
                    });
                }
                if (interval.b != path.nextIndex(index)) {
                    try intervals.append(.{
                        .object_index = object_index,
                        .a = path.nextIndex(index),
                        .b = interval.b,
                    });
                }
                return;
            }
            if (interval.a == path.nextIndex(index) and interval.b == index) {
                _ = intervals.swapRemove(i - 1);
                try loops.append(.{ .object_index = object_index });
                return;
            }
            if (interval.a == path.nextIndex(index)) {
                _ = intervals.swapRemove(i - 1);
                b = interval.b;
            }
            if (interval.b == index) {
                _ = intervals.swapRemove(i - 1);
                a = interval.a;
            }
        }
    }
    try intervals.append(.{ .object_index = object_index, .a = a, .b = b });
}

pub fn toggleLoop(object_index: u32) !void {
    var i: usize = loops.items.len;
    while (i > 0) : (i -= 1) {
        const loop = loops.items[i - 1];
        if (loop.object_index == object_index) {
            _ = loops.swapRemove(i - 1);
            return;
        }
    }
    i = intervals.items.len;
    while (i > 0) : (i -= 1) {
        const interval = intervals.items[i - 1];
        if (interval.object_index == object_index) {
            _ = intervals.swapRemove(i - 1);
        }
    }
    try loops.append(.{ .object_index = object_index });
}

pub fn selectAll() !void {
    clear();
    for (canvas.objects.items) |object, object_index| {
        if (object.toPath().isLooped()) {
            loops.append(.{ .object_index = object_index });
        } else {
            intervals.append(.{ .object_index = object_index, .a = 0, .b = object.toPath().len() - 1 });
        }
    }
}

pub fn gen(stroke: geometry.Stroke, color: [4]u8, buffer: *render.Buffer) !void {
    for (intervals.items) |interval| {
        const path = interval.getPath();
        var dir: ?geometry.Vec2 = null;
        var index: u32 = interval.a;
        while (index != interval.b) : (index = path.nextIndex(index))
            dir = try stroke.genSegment(dir, path.getArc(index), color, buffer);
        try stroke.genCap(path.positions[index], dir, null, color, buffer);
    }
    for (loops.items) |loop| {
        try stroke.genPath(loop.getPath(), color, buffer);
    }
}

pub const add_point = struct {
    pub fn can() bool {
        return intervals.items.len == 0 and loops.items.len == 0;
    }

    pub fn do(pos: geometry.Vec2) !void {
        std.debug.assert(can());
        try canvas.objects.append(try canvas.Object.init(canvas.objects.allocator, pos));
        try intervals.append(.{ .object_index = @intCast(u32, canvas.objects.items.len - 1), .a = 0, .b = 0 });
    }
};

pub const append = struct {
    pub fn can() bool {
        return loops.items.len == 0 and intervals.items.len == 1 and
            intervals.items[0].isLooseEnd();
    }

    pub fn gen(pos: geometry.Vec2, stroke: geometry.Stroke, color: [4]u8, buffer: *render.Buffer) !void {
        std.debug.assert(can());
        const interval = intervals.items[0];
        try stroke.genPath(.{
            .positions = &.{ interval.getPath().positions[interval.a], pos },
            .angles = &.{0},
        }, color, buffer);
    }

    pub fn do(pos: geometry.Vec2) !void {
        std.debug.assert(can());
        const interval = &intervals.items[0];
        if (interval.a == 0)
            interval.getObject().reverse();
        try interval.getObject().append(0, pos);
        interval.a = interval.getPath().len() - 1;
        interval.b = interval.getPath().len() - 1;
    }
};

pub const connect = struct {
    pub fn can() bool {
        return loops.items.len == 0 and intervals.items.len == 2 and
            intervals.items[0].isLooseEnd() and intervals.items[1].isLooseEnd();
    }

    pub fn do() !void {
        std.debug.assert(can());
        const interval0 = &intervals.items[0];
        const interval1 = &intervals.items[1];
        if (interval0.object_index == interval1.object_index) {
            try interval0.getObject().loop(0);
            _ = intervals.pop();
            interval0.a = interval0.getPath().len() - 1;
            interval0.b = 0;
        } else {
            if (interval0.object_index > interval1.object_index)
                std.mem.swap(Interval, interval0, interval1);
            if (interval0.a == 0)
                interval0.getObject().reverse();
            if (interval1.a != 0)
                interval1.getObject().reverse();
            const connection_index = interval0.getPath().len() - 1;
            try interval0.getObject().appendPath(0, interval1.getPath());
            var object = canvas.objects.swapRemove(interval1.object_index);
            object.deinit();
            _ = intervals.pop();
            interval0.a = connection_index;
            interval0.b = connection_index + 1;
        }
    }
};

pub const delete = struct {
    pub fn can() bool {
        for (intervals.items) |interval| if (!interval.isSingleNode()) return true;
        return loops.items.len > 0;
    }

    pub fn do() !void {
        var old_objects = canvas.objects;
        canvas.objects = std.ArrayList(canvas.Object).init(canvas.objects.allocator);
        var object_index: u32 = 0;
        while (object_index < old_objects.items.len) : (object_index += 1) {
            const object = &old_objects.items[object_index];
            if (object.toPath().isLooped()) {
                try addUnselectedObjectLoop(object, .{ .object_index = object_index });
            } else {
                try addUnselectedObjectInterval(object, .{ .object_index = object_index, .a = 0, .b = object.toPath().len() - 1 });
            }
        }
        for (old_objects.items) |*object| object.deinit();
        old_objects.deinit();
        clear();
    }

    fn addUnselectedObjectLoop(object: *canvas.Object, o_loop: Loop) !void {
        for (loops.items) |loop| {
            if (loop.object_index == o_loop.object_index)
                return;
        }
        for (intervals.items) |interval| {
            if (interval.object_index == o_loop.object_index and !interval.isSingleNode())
                return addUnselectedObjectInterval(object, .{ .object_index = interval.object_index, .a = interval.b, .b = interval.a });
        }
        try canvas.objects.append(try object.clone());
    }

    fn addUnselectedObjectInterval(object: *canvas.Object, o_interval: Interval) !void {
        for (intervals.items) |interval| {
            if (interval.object_index == o_interval.object_index and !interval.isSingleNode() and o_interval.containsSegment(interval.a)) {
                if (interval.a != o_interval.a)
                    try addUnselectedObjectInterval(object, .{ .object_index = interval.object_index, .a = o_interval.a, .b = interval.a });
                if (interval.b != o_interval.b)
                    try addUnselectedObjectInterval(object, .{ .object_index = interval.object_index, .a = interval.b, .b = o_interval.b });
                return;
            }
        }
        const path = object.toPath();
        var new_object = try canvas.Object.init(object.allocator, path.positions[o_interval.a]);
        var i = o_interval.a;
        while (i != o_interval.b) : (i = path.nextIndex(i))
            try new_object.append(path.angles[i], path.positions[path.nextIndex(i)]);
        try canvas.objects.append(new_object);
    }
};

pub const move = struct {
    pub fn can() bool {
        return intervals.items.len > 0 or loops.items.len > 0;
    }

    fn isNodeSelected(object_index: u32, index: u32) bool {
        for (intervals.items) |interval| {
            if (interval.object_index == object_index and interval.containsNode(index))
                return true;
        }
        return false;
    }

    pub fn gen(offset: geometry.Vec2, stroke: geometry.Stroke, color: [4]u8, buffer: *render.Buffer) !void {
        std.debug.assert(can());
        for (intervals.items) |interval| {
            const path = interval.getPath();
            var dir: ?geometry.Vec2 = null;
            if (path.isLooped() or interval.a > 0) {
                var arc = path.getArc(path.prevIndex(interval.a));
                arc.pos_b += offset;
                if (!isNodeSelected(interval.object_index, path.prevIndex(interval.a)))
                    _ = try stroke.genSegment(null, arc, color, buffer);
                dir = arc.dirB();
            }
            var index: u32 = interval.a;
            while (index != interval.b) : (index = path.nextIndex(index)) {
                var arc = path.getArc(index);
                arc.pos_a += offset;
                arc.pos_b += offset;
                dir = try stroke.genSegment(dir, arc, color, buffer);
            }
            if (path.isLooped() or interval.b < path.len() - 1) {
                var arc = path.getArc(interval.b);
                arc.pos_a += offset;
                if (isNodeSelected(interval.object_index, path.nextIndex(interval.b)))
                    arc.pos_b += offset;
                dir = try stroke.genSegment(dir, arc, color, buffer);
                index = path.nextIndex(interval.b);
            }
            try stroke.genCap(path.positions[index], dir, null, color, buffer);
        }
        for (loops.items) |loop| {
            const path = loop.getPath();
            var dir = path.getArc(path.prevIndex(0)).dirB();
            var index: u32 = 0;
            while (index < path.len()) : (index += 1) {
                var arc = path.getArc(index);
                arc.pos_a += offset;
                arc.pos_b += offset;
                dir = try stroke.genSegment(dir, arc, color, buffer);
            }
        }
    }

    pub fn do(offset: geometry.Vec2) !void {
        std.debug.assert(can());
        for (intervals.items) |interval| {
            var index: u32 = interval.a;
            while (index != interval.b) : (index = interval.getPath().nextIndex(index))
                interval.getObject().positions.items[index] += offset;
            interval.getObject().positions.items[index] += offset;
        }
        for (loops.items) |loop| {
            var index: u32 = 0;
            while (index < loop.getPath().len()) : (index += 1)
                loop.getObject().positions.items[index] += offset;
        }
    }
};

pub const change_angle = struct {
    pub fn can() bool {
        return loops.items.len == 0 and intervals.items.len == 1 and
            intervals.items[0].isSingleSegment();
    }

    pub fn gen(angle: f32, stroke: geometry.Stroke, color: [4]u8, buffer: *render.Buffer) !void {
        std.debug.assert(can());
        const interval = intervals.items[0];
        const path = interval.getPath();
        try stroke.genPath(.{
            .positions = &.{ path.positions[interval.a], path.positions[interval.b] },
            .angles = &.{angle},
        }, color, buffer);
    }

    pub fn do(angle: f32) !void {
        std.debug.assert(can());
        const interval = intervals.items[0];
        interval.getObject().angles.items[interval.a] = angle;
    }
};

pub const split_segment = struct {
    pub fn can() bool {
        return loops.items.len == 0 and intervals.items.len == 1 and
            intervals.items[0].isSingleSegment();
    }

    pub fn gen(param: f32, stroke: geometry.Stroke, color: [4]u8, buffer: *render.Buffer) !void {
        std.debug.assert(can());
        const interval = intervals.items[0];
        const arc = interval.getPath().getArc(interval.a);
        try stroke.genCap(arc.point(param), null, null, color, buffer);
    }

    pub fn do(param: f32) !void {
        std.debug.assert(can());
        const interval = &intervals.items[0];
        try interval.getObject().splitSegment(interval.a, param);
        interval.a = interval.getPath().nextIndex(interval.a);
        interval.b = interval.a;
    }
};
