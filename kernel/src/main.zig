const std = @import("std");
const builtin = @import("builtin");
const limine = @import("limine");

const debug = @import("debug.zig");
const arch = @import("arch.zig");
const screen = @import("screen.zig");
const console = @import("console.zig");

const log = std.log.scoped(.core);

pub const std_options = .{
    .logFn = debug.logFn,
    .log_level = switch (builtin.mode) {
        .Debug => .debug,
        else => .info,
    },
};

export var base_revision: limine.BaseRevision = .{ .revision = 2 };

pub export fn _start() noreturn {
    if (!base_revision.is_supported()) {
        arch.cpu.hang();
    }

    screen.init();
    console.init();

    log.info("Entering stage 1 of kernel...", .{});

    while (true) {}
}

pub fn panic(msg: []const u8, error_return_trace: ?*std.builtin.StackTrace, ret_addr: ?usize) noreturn {
    _ = error_return_trace;
    _ = ret_addr;
    log.err("*Panic*\n{s}", .{msg});

    while (true) {}
}
