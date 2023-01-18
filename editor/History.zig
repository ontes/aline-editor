const std = @import("std");
const ImageSelection = @import("ImageSelection.zig");

const History = @This();

level: u32 = 0,
max_len: u32 = std.math.maxInt(u32),
entries: std.ArrayList(ImageSelection),

pub fn init(allocator: std.mem.Allocator) History {
    return .{ .entries = std.ArrayList(ImageSelection).init(allocator) };
}

pub fn deinit(history: History) void {
    for (history.entries.items) |*sel|
        sel.deinit();
    history.entries.deinit();
}

pub fn get(history: History) *ImageSelection {
    return &history.entries.items[history.entries.items.len - 1 - history.level];
}

pub fn getPrev(history: History) *ImageSelection {
    return &history.entries.items[history.entries.items.len - 2 - history.level];
}

pub fn add(history: *History, sel: ImageSelection) !void {
    while (history.level > 0) : (history.level -= 1)
        history.entries.pop().deinit();

    try history.entries.append(sel);

    while (history.entries.items.len > history.max_len)
        history.entries.orderedRemove(0).deinit();
}

pub fn undo(history: *History) bool {
    if (history.level + 1 < history.entries.items.len) {
        history.level += 1;
        return true;
    }
    return false;
}

pub fn redo(history: *History) bool {
    if (history.level > 0) {
        history.level -= 1;
        return true;
    }
    return false;
}
