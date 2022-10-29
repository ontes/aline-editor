const std = @import("std");
const editor = @import("editor.zig");

const history_size = 16;
var history_level: u32 = 0;

var objects_history: [history_size]std.ArrayList(editor.Object) = undefined;

pub fn init(allocator: std.mem.Allocator) void {
    for (objects_history) |*objects| {
        objects.* = std.ArrayList(editor.Object).init(allocator);
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
    try copyObjects(editor.objects.items, &objects_history[0]);
}

pub fn undo() !void {
    history_level += 1;
    rotateHistory(1);
    try copyObjects(objects_history[0].items, &editor.objects);
}

pub fn redo() !void {
    if (history_level == 0) return;
    history_level -= 1;
    rotateHistory(history_size - 1);
    try copyObjects(objects_history[0].items, &editor.objects);
}

fn rotateHistory(amount: u32) void {
    std.mem.rotate(std.ArrayList(editor.Object), &objects_history, amount);
}

fn copyObjects(from: []editor.Object, to: *std.ArrayList(editor.Object)) !void {
    cleanObjects(to);
    for (from) |*t|
        try to.append(try t.clone());
}

fn cleanObjects(objects: *std.ArrayList(editor.Object)) void {
    for (objects.items) |*object|
        object.deinit();
    objects.clearRetainingCapacity();
}
