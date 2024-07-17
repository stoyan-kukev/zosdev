const std = @import("std");
const cpu = @import("cpu.zig");
const tss = @import("tss.zig");

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
    // User code 64 bit with ring 3
    .ucode_64 = 0x38 | 0x03,
    // User data 64 bit with ring 3
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

    const gs_base = cpu.Msr.read(.GS_BASE);

    gdtd = .{
        .offset = @intFromPtr(&gdt),
        .size = @sizeOf(@TypeOf(gdt)) - 1,
    };
    cpu.lgdt(&gdtd);

    asm volatile (
        \\ push %[kcode]
        \\ lea 1f(%%rip), %%rax
        \\ push %%rax
        \\ lretq
        \\ 1:
        \\ mov %[kdata], %%eax
        \\ mov %%eax, %%ds
        \\ mov %%eax, %%es
        \\ mov %%eax, %%fs
        \\ mov %%eax, %%gs
        \\ mov %%eax, %%ss
        :
        : [kcode] "i" (selectors.kcode_64),
          [kdata] "i" (selectors.kdata_64),
        : "rax", "rcx", "memory"
    );

    cpu.Msr.write(.GS_BASE, gs_base);
}

pub fn setTss(entry: *const tss.Entry) void {
    gdt[9] = @bitCast(((@sizeOf(tss.Entry) - 1) & 0xffff) | ((@intFromPtr(entry) & 0xffffff) << 16) | (0b1001 << 40) | (1 << 47) | (((@intFromPtr(entry) >> 24) & 0xff) << 56));
    gdt[10] = @bitCast(@intFromPtr(entry) >> 32);
    cpu.ltr(selectors.tss);
}
