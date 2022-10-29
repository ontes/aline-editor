const std = @import("std");

var prev_time: u128 = 0;
var time: u128 = 0;
var frames_per_second: u32 = 0;
var frame_counter: u32 = 0;

pub fn update() void {
    prev_time = time;
    time = @intCast(u128, std.time.nanoTimestamp());

    frame_counter += 1;
    if (oncePerMs(1000)) {
        frames_per_second = frame_counter;
        frame_counter = 0;
    }
}

pub inline fn deltaNs() u128 {
    return time - prev_time;
}

pub inline fn deltaMs() u64 {
    return deltaNs() / std.time.ns_per_ms;
}

pub inline fn deltaSeconds() f32 {
    return @intToFloat(f32, deltaMs()) / 1000;
}

pub inline fn oncePerNs(interval: u128) bool {
    return (time / interval) != (prev_time / interval);
}

pub inline fn oncePerMs(interval: u64) bool {
    return oncePerNs(interval * std.time.ns_per_ms);
}

pub inline fn fps() u32 {
    return frames_per_second;
}
