const std = @import("std");
const editor = @import("editor.zig");

const history_size = 16;
var history_level: u32 = 0;

var paths_history: [history_size]std.ArrayList(editor.DynamicPath) = undefined;

pub fn init(allocator: std.mem.Allocator) void {
    for (paths_history) |*paths| {
        paths.* = std.ArrayList(editor.DynamicPath).init(allocator);
    }
}

pub fn deinit() void {
    for (paths_history) |*paths| {
        cleanPaths(paths);
        paths.deinit();
    }
}

pub fn step() !void {
    history_level = 0;
    rotateHistory(history_size - 1);
    try copyPaths(editor.paths.items, &paths_history[0]);
}

pub fn undo() !void {
    history_level += 1;
    rotateHistory(1);
    try copyPaths(paths_history[0].items, &editor.paths);
}

pub fn redo() !void {
    if (history_level == 0) return;
    history_level -= 1;
    rotateHistory(history_size - 1);
    try copyPaths(paths_history[0].items, &editor.paths);
}

fn rotateHistory(amount: u32) void {
    std.mem.rotate(std.ArrayList(editor.DynamicPath), &paths_history, amount);
}

fn copyPaths(from: []editor.DynamicPath, to: *std.ArrayList(editor.DynamicPath)) !void {
    cleanPaths(to);
    for (from) |*t|
        try to.append(try t.clone());
}

fn cleanPaths(paths: *std.ArrayList(editor.DynamicPath)) void {
    for (paths.items) |*path|
        path.deinit();
    paths.clearRetainingCapacity();
}
