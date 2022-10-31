const std = @import("std");
const canvas = @import("canvas.zig");

const history_size = 16;
var history_level: u32 = 0;

var objects_history: [history_size]std.ArrayList(canvas.Object) = undefined;

pub fn init(allocator: std.mem.Allocator) void {
    for (objects_history) |*objects| {
        objects.* = std.ArrayList(canvas.Object).init(allocator);
    }
}

pub fn deinit() void {
    for (objects_history) |*objects| {
        cleanObjects(objects);
        objects.deinit();
    }
}

pub fn step() !void {
    history_level = 0;
    rotateHistory(history_size - 1);
    try copyObjects(canvas.objects.items, &objects_history[0]);
    try canvas.updateObjectsBuffer();
}

pub fn undo() !void {
    history_level += 1;
    rotateHistory(1);
    try copyObjects(objects_history[0].items, &canvas.objects);
    try canvas.updateObjectsBuffer();
}

pub fn redo() !void {
    if (history_level == 0) return;
    history_level -= 1;
    rotateHistory(history_size - 1);
    try copyObjects(objects_history[0].items, &canvas.objects);
    try canvas.updateObjectsBuffer();
}

fn rotateHistory(amount: u32) void {
    std.mem.rotate(std.ArrayList(canvas.Object), &objects_history, amount);
}

fn copyObjects(from: []canvas.Object, to: *std.ArrayList(canvas.Object)) !void {
    cleanObjects(to);
    for (from) |*t|
        try to.append(try t.clone());
}

fn cleanObjects(objects: *std.ArrayList(canvas.Object)) void {
    for (objects.items) |*object|
        object.deinit();
    objects.clearRetainingCapacity();
}
