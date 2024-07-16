const std = @import("std");
const cpu = @import("cpu.zig");

pub const Entry = packed struct(u64) {
    limit_a: u16,
    base_a: u24,
    access: packed struct(u8) {
        accessed: bool = false,
        read_write: bool,
        direction_conforming: bool,
        executable: bool,
        type: enum(u1) { system, normal },
        dpl: u2,
        present: bool,
    },
    limit_b: u4,
    flags: packed struct(u4) {
        reserved: u1 = 0,
        long_code: bool,
        size: bool,
        granularity: bool,
    },
    base_b: u8,
};

/// Selector (pointer) to the GDT
pub const Gdtd = packed struct(u80) {
    size: u16,
    offset: u64,
};

const log = std.log.scoped(.gdt);

pub const selectors = .{
    .kcode_16 = 0x08,
    .kdata_16 = 0x10,
    .kcode_32 = 0x18,
    .kdata_32 = 0x20,
    .kcode_64 = 0x28,
    .kdata_64 = 0x30,
    .ucode_64 = 0x38 | 0x03,
    .udata_64 = 0x40 | 0x03,
    .tss = 0x48,
};

var gdt = [_]Entry{
    @bitCast(@as(u64, 0)), // Null descriptor
    .{
        .limit_a = 65535,
        .base_a = 0,
        .access = .{
            .read_write = true,
            .direction_conforming = false,
            .executable = true,
            .type = .normal,
            .dpl = 0,
            .present = true,
        },
        .limit_b = 0,
        .flags = .{
            .long_code = false,
            .size = false,
            .granularity = false,
        },
        .base_b = 0,
    },
    .{
        .limit_a = 65535,
        .base_a = 0,
        .access = .{
            .read_write = true,
            .direction_conforming = false,
            .executable = false,
            .type = .normal,
            .dpl = 0,
            .present = true,
        },
        .limit_b = 0,
        .flags = .{
            .long_code = false,
            .size = false,
            .granularity = false,
        },
        .base_b = 0,
    },
    .{
        .limit_a = 65535,
        .base_a = 0,
        .access = .{
            .read_write = true,
            .direction_conforming = false,
            .executable = true,
            .type = .normal,
            .dpl = 0,
            .present = true,
        },
        .limit_b = 15,
        .flags = .{
            .long_code = false,
            .size = true,
            .granularity = true,
        },
        .base_b = 0,
    },
    .{
        .limit_a = 65535,
        .base_a = 0,
        .access = .{
            .read_write = true,
            .direction_conforming = false,
            .executable = false,
            .type = .normal,
            .dpl = 0,
            .present = true,
        },
        .limit_b = 15,
        .flags = .{
            .long_code = false,
            .size = true,
            .granularity = true,
        },
        .base_b = 0,
    },
    .{
        .limit_a = 0,
        .base_a = 0,
        .access = .{
            .read_write = true,
            .direction_conforming = false,
            .executable = true,
            .type = .normal,
            .dpl = 0,
            .present = true,
        },
        .limit_b = 0,
        .flags = .{
            .long_code = true,
            .size = false,
            .granularity = false,
        },
        .base_b = 0,
    },
    .{
        .limit_a = 0,
        .base_a = 0,
        .access = .{
            .read_write = true,
            .direction_conforming = false,
            .executable = false,
            .type = .normal,
            .dpl = 0,
            .present = true,
        },
        .limit_b = 0,
        .flags = .{
            .long_code = false,
            .size = false,
            .granularity = false,
        },
        .base_b = 0,
    },
    .{
        .limit_a = 0,
        .base_a = 0,
        .access = .{
            .read_write = true,
            .direction_conforming = false,
            .executable = false,
            .type = .normal,
            .dpl = 3,
            .present = true,
        },
        .limit_b = 0,
        .flags = .{
            .long_code = false,
            .size = false,
            .granularity = false,
        },
        .base_b = 0,
    },
    .{
        .limit_a = 0,
        .base_a = 0,
        .access = .{
            .read_write = true,
            .direction_conforming = false,
            .executable = true,
            .type = .normal,
            .dpl = 3,
            .present = true,
        },
        .limit_b = 0,
        .flags = .{
            .long_code = true,
            .size = false,
            .granularity = false,
        },
        .base_b = 0,
    },
    // TSS
    @bitCast(@as(u64, 0)),
    @bitCast(@as(u64, 0)),
};

var gdtd: Gdtd = undefined;

pub fn init() void {
    log.debug("Initializing...", .{});
    defer log.debug("Initialization complete!", .{});

    gdtd = .{
        .offset = @intFromPtr(&gdt),
        .size = @sizeOf(@TypeOf(gdt)) - 1,
    };

    log.debug("Loading GDT...", .{});
    // const gs_base = cpu.Msr.read(.GS_BASE);
}
