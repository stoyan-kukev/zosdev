const std = @import("std");
const z86_64 = @import("z86_64");
const limine = @import("limine");
const builtin = @import("builtin");
const debug = @import("debug.zig");
const uart = @import("uart.zig");
const gdt = @import("arch/x86_64/gdt.zig");
const idt = @import("arch/x86_64/idt.zig");
const paging = @import("arch/x86_64/paging.zig");

const log = std.log.scoped(.core);

pub const std_options = .{
    .logFn = debug.logFn,
    .log_level = switch (builtin.mode) {
        .Debug => .debug,
        else => .info,
    },
};

pub fn panic(msg: []const u8, error_return_trace: ?*std.builtin.StackTrace, ret_addr: ?usize) noreturn {
    _ = error_return_trace;
    _ = ret_addr;
    log.err("*Panic*\n{s}", .{msg});

    while (true) {}
}

export fn _start() callconv(.C) noreturn {
    init() catch |err| {
        log.err("Initialization failed: {}", .{err});
    };
    while (true) {}
}

pub fn init() !void {
    uart.init(uart.Speed.fromBaudrate(9600).?);

    const vendor = z86_64.cpuid.getCpuVendor();
    log.info("Vendor: {s}", .{vendor});

    gdt.init();
    idt.init();
    paging.init();
}
