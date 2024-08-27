const std = @import("std");

const arch = @import("../arch.zig");

const SpinLock = @This();

locked: std.atomic.Value(u32) = .{ .raw = 0 },
ref_count: std.atomic.Value(usize) = .{ .raw = 0 },
interrupts_was_enabled: bool = false,

pub fn lock(self: *SpinLock) void {
    _ = self.ref_count.fetchAdd(1, .monotonic);

    const interrupts_was_enabled = arch.cpu.interrupts.status();

    arch.cpu.interrupts.disable();

    while (true) {
        if (self.locked.swap(1, .acquire) == 0) {
            break;
        }

        while (self.locked.fetchAdd(0, .monotonic) != 0) {
            if (interrupts_was_enabled) arch.cpu.interrupts.enable();

            std.atomic.spinLoopHint();

            arch.cpu.interrupts.disable();
        }
    }

    _ = self.ref_count.fetchSub(1, .monotonic);

    @fence(.acquire);

    self.interrupts_was_enabled = interrupts_was_enabled;
}

pub fn unlock(self: *SpinLock) void {
    self.locked.store(0, .release);
    @fence(.release);

    if (self.interrupts_was_enabled) arch.cpu.interrupts.enable();
}
