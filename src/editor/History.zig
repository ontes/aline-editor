const std = @import("std");
const Drawing = @import("Drawing.zig");
const Selection = @import("Selection.zig");

pub const Entry = struct {
    drawing: Drawing,
    selection: Selection,

    pub fn init(allocator: std.mem.Allocator) Entry {
        return .{
            .drawing = Drawing.init(allocator),
            .selection = Selection.init(allocator),
        };
    }

    pub fn clone(entry: Entry) !Entry {
        var selection = entry.selection;
        return .{
            .drawing = try entry.drawing.clone(),
            .selection = try selection.clone(),
        };
    }

    pub fn cloneDrawingOnly(entry: Entry) !Entry {
        return .{
            .drawing = try entry.drawing.clone(),
            .selection = Selection.init(entry.selection.allocator),
        };
    }

    pub fn deinit(entry: Entry) void {
        var drawing = entry.drawing;
        var selection = entry.selection;
        drawing.deinit();
        selection.deinit();
    }
};

const History = @This();

level: u32 = 0,
max_len: u32 = std.math.maxInt(u32),
entries: std.ArrayList(Entry),

pub fn init(allocator: std.mem.Allocator) History {
    return .{ .entries = std.ArrayList(Entry).init(allocator) };
}

pub fn deinit(history: History) void {
    for (history.entries.items) |*entry|
        entry.deinit();
    history.entries.deinit();
}

pub fn get(history: History) *Entry {
    return &history.entries.items[history.entries.items.len - 1 - history.level];
}

pub fn getPrev(history: History) *Entry {
    return &history.entries.items[history.entries.items.len - 2 - history.level];
}

pub fn add(history: *History, entry: Entry) !void {
    while (history.level > 0) : (history.level -= 1)
        history.entries.pop().deinit();

    try history.entries.append(entry);

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
