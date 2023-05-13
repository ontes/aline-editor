const std = @import("std");
const ImageSelection = @import("ImageSelection.zig");

const History = @This();

level: usize = 0,
max_len: usize = 101,
entries: std.ArrayList(ImageSelection),

pub fn init(allocator: std.mem.Allocator) History {
    return .{ .entries = std.ArrayList(ImageSelection).init(allocator) };
}

pub fn deinit(history: History) void {
    for (history.entries.items) |*is|
        is.deinit();
    history.entries.deinit();
}

pub fn clear(history: *History) void {
    for (history.entries.items) |*is|
        is.deinit();
    history.entries.clearRetainingCapacity();
}

pub fn get(history: History) *ImageSelection {
    return &history.entries.items[history.entries.items.len - 1 - history.level];
}

pub fn getPrev(history: History) *ImageSelection {
    return &history.entries.items[history.entries.items.len - 2 - history.level];
}

pub fn add(history: *History, is: ImageSelection) !void {
    while (history.level > 0) : (history.level -= 1)
        history.entries.pop().deinit();

    try history.entries.append(is);

    while (history.entries.items.len > history.max_len)
        history.entries.orderedRemove(0).deinit();
}

pub fn canUndo(history: History) bool {
    return history.level + 1 < history.entries.items.len;
}
pub fn undo(history: *History) void {
    std.debug.assert(history.canUndo());
    history.level += 1;
}

pub fn canRedo(history: History) bool {
    return history.level > 0;
}
pub fn redo(history: *History) void {
    std.debug.assert(history.canRedo());
    history.level -= 1;
}
