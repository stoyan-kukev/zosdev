const gdt = @import("gdt.zig");
const idt = @import("idt.zig");

pub inline fn hang() noreturn {
    while (true) interrupts.hlt();
}

pub const segments = struct {
    /// Get the Code Segment Selector
    pub inline fn cs() u16 {
        return asm volatile ("mov %cs, %[result]"
            : [result] "={rax}" (-> u16),
        );
    }

    /// Load the Global Descriptor Table
    pub inline fn lgdt(gdtr: *const gdt.GlobalDescriptorTable.Register) void {
        asm volatile ("lgdt (%[gdtr])"
            :
            : [gdtr] "{rax}" (gdtr),
        );
    }

    pub noinline fn reloadSegments() void {
        asm volatile (
            \\pushq $0x08
            \\pushq $reloadCodeSegment
            \\lretq
            \\
            \\reloadCodeSegment:
            \\  mov $0x10, %ax
            \\  mov %ax, %es
            \\  mov %ax, %ss
            \\  mov %ax, %ds
            \\  mov %ax, %fs
            \\  mov %ax, %gs
        );
    }

    /// Load the Interrupt Descriptor Table
    pub inline fn lidt(idtr: *const idt.InterruptDescriptorTable.Register) void {
        asm volatile ("lidt (%[idtr])"
            :
            : [idtr] "{rax}" (idtr),
        );
    }

    /// Load the Task Register (Which is a Task State Segment Selector in the Global Descriptor Table)
    pub inline fn ltr(tr: u16) void {
        asm volatile ("ltr %[tr]"
            :
            : [tr] "{rax}" (tr),
        );
    }
};

pub const registers = struct {
    pub const RFlags = packed struct(u64) {
        cf: u1,
        reserved_1: u1,
        pf: u1,
        reserved_2: u1,
        af: u1,
        reserved_3: u1,
        zf: u1,
        sf: u1,
        tf: u1,
        @"if": u1,
        df: u1,
        of: u1,
        iopl: u2,
        nt: u1,
        reserved_4: u1,
        rf: u1,
        vm: u1,
        ac: u1,
        vif: u1,
        vip: u1,
        id: u1,
        reserved_5: u42,

        /// Write the Flags Register
        pub inline fn write(flags: RFlags) void {
            asm volatile (
                \\push %[result]
                \\popfq
                :
                : [result] "{rax}" (flags),
            );
        }

        /// Read the Flags Register
        pub inline fn read() RFlags {
            return asm volatile (
                \\pushfq
                \\pop %[result]
                : [result] "={rax}" (-> RFlags),
            );
        }
    };

    pub const ModelSpecific = struct {
        pub const Register = enum(u32) {
            apic_base = 0x0000_001B,
            efer = 0xC000_0080,
            star = 0xC000_0081,
            lstar = 0xC000_0082,
            cstar = 0xC000_0083,
            sf_mask = 0xC000_0084,
            gs_base = 0xC000_0101,
            kernel_gs_base = 0xC000_0102,
        };

        /// Write to a Model Specific Register
        pub inline fn write(register: Register, value: usize) void {
            const value_low: u32 = @truncate(value);
            const value_high: u32 = @truncate(value >> 32);

            asm volatile ("wrmsr"
                :
                : [register] "{ecx}" (@intFromEnum(register)),
                  [value_low] "{eax}" (value_low),
                  [value_high] "{edx}" (value_high),
            );
        }

        /// Read a Model Specific Register
        pub inline fn read(register: Register) u64 {
            var value_low: u32 = undefined;
            var value_high: u32 = undefined;

            asm volatile ("rdmsr"
                : [value_low] "={eax}" (value_low),
                  [value_high] "={edx}" (value_high),
                : [register] "{ecx}" (@intFromEnum(register)),
            );

            return (@as(usize, value_high) << 32) | value_low;
        }
    };

    pub const Cr2 = struct {
        pub inline fn write(value: u64) void {
            asm volatile ("mov %[value], %cr2"
                :
                : [value] "{rax}" (value),
                : "memory"
            );
        }

        pub inline fn read() u64 {
            return asm volatile ("mov %cr2, %[result]"
                : [result] "={rax}" (-> u64),
            );
        }
    };

    pub const Cr3 = struct {
        pub inline fn write(value: u64) void {
            asm volatile ("mov %[value], %cr3"
                :
                : [value] "{rax}" (value),
                : "memory"
            );
        }

        pub inline fn read() u64 {
            return asm volatile ("mov %cr3, %[result]"
                : [result] "={rax}" (-> u64),
            );
        }
    };
};

pub const interrupts = struct {
    pub inline fn status() bool {
        return registers.RFlags.read().@"if" == 1;
    }

    pub inline fn enable() void {
        asm volatile ("sti");
    }

    pub inline fn disable() void {
        asm volatile ("cli");
    }
    pub inline fn hlt() void {
        asm volatile ("hlt");
    }
};

pub inline fn inb(port: u16) u8 {
    return asm volatile ("inb %[port], %[result]"
        : [result] "={al}" (-> u8),
        : [port] "N{dx}" (port),
    );
}

pub inline fn inw(port: u16) u16 {
    return asm volatile ("inw %[port], %[result]"
        : [result] "={ax}" (-> u16),
        : [port] "N{dx}" (port),
    );
}

pub inline fn inl(port: u16) u32 {
    return asm volatile ("inl %[port], %[result]"
        : [result] "={eax}" (-> u32),
        : [port] "N{dx}" (port),
    );
}

pub inline fn outb(port: u16, data: u8) void {
    asm volatile ("outb %[data], %[port]"
        :
        : [data] "{al}" (data),
          [port] "N{dx}" (port),
    );
}

pub inline fn outw(port: u16, data: u16) void {
    asm volatile ("outw %[data], %[port]"
        :
        : [data] "{ax}" (data),
          [port] "N{dx}" (port),
    );
}

pub inline fn outl(port: u16, data: u32) void {
    asm volatile ("outl %[data], %[port]"
        :
        : [data] "{eax}" (data),
          [port] "N{dx}" (port),
    );
}

pub inline fn lidt(idtd: *const idt.Idtd) void {
    asm volatile ("lidt (%%rax)"
        :
        : [idtd] "{rax}" (idtd),
    );
}

pub inline fn lgdt(gdtd: *const gdt.Gdtd) void {
    asm volatile ("lgdt (%%rax)"
        :
        : [gdtd] "{rax}" (gdtd),
    );
}

pub inline fn ltr(selector: u16) void {
    asm volatile ("ltr %[selector]"
        :
        : [selector] "r" (selector),
    );
}

pub inline fn invlpg(addr: usize) void {
    asm volatile ("invlpg (%[addr])"
        :
        : [addr] "r" (addr),
        : "memory"
    );
}

pub inline fn getLowEflags() u16 {
    return @truncate(asm volatile (
        \\pushf
        \\pop %[res]
        : [res] "=r" (-> usize),
    ));
}

pub inline fn getEflags() u32 {
    return @truncate(asm volatile (
        \\pushfd
        \\pop %[res]
        : [res] "=r" (-> usize),
    ));
}

pub inline fn getRflags() u64 {
    return asm volatile (
        \\pushfq
        \\pop %[res]
        : [res] "=r" (-> usize),
    );
}

pub const Cr2 = struct {
    pub inline fn read() usize {
        return asm volatile ("mov %cr2, %[res]"
            : [res] "=r" (-> usize),
        );
    }
};

pub const Cr3 = struct {
    pub inline fn write(value: usize) void {
        asm volatile ("mov %[value], %cr3"
            :
            : [value] "r" (value),
            : "memory"
        );
    }

    pub inline fn read() usize {
        return asm volatile ("mov %cr3, %[res]"
            : [res] "=r" (-> usize),
        );
    }
};

pub const Msr = struct {
    pub const Register = enum(u32) {
        APIC_BASE = 0x0000_001B,
        EFER = 0xC000_0080,
        STAR = 0xC000_0081,
        LSTAR = 0xC000_0082,
        CSTAR = 0xC000_0083,
        SF_MASK = 0xC000_0084,
        GS_BASE = 0xC000_0101,
        KERNEL_GS_BASE = 0xC000_0102,
    };

    pub inline fn write(register: Register, value: usize) void {
        const value_low: u32 = @truncate(value);
        const value_high: u32 = @truncate(value >> 32);

        asm volatile ("wrmsr"
            :
            : [register] "{ecx}" (@intFromEnum(register)),
              [value_low] "{eax}" (value_low),
              [value_high] "{edx}" (value_high),
        );
    }

    pub inline fn read(register: Register) usize {
        var value_low: u32 = undefined;
        var value_high: u32 = undefined;

        asm volatile ("rdmsr"
            : [value_low] "={eax}" (value_low),
              [value_high] "={edx}" (value_high),
            : [register] "{ecx}" (@intFromEnum(register)),
        );

        return (@as(usize, value_high) << 32) | value_low;
    }
};

pub const ContextFrame = packed struct {
    es: u64,
    ds: u64,
    r15: u64,
    r14: u64,
    r13: u64,
    r12: u64,
    r11: u64,
    r10: u64,
    r9: u64,
    r8: u64,
    rdi: u64,
    rsi: u64,
    rbp: u64,
    rdx: u64,
    rcx: u64,
    rbx: u64,
    rax: u64,
    int_num: u64,
    err: u64,
    rip: u64,
    cs: u64,
    eflags: u64,
    rsp: u64,
    ss: u64,
};

pub const CoreInfo = packed struct {
    kernel_stack: u64,
    user_stack: u64,
    id: u64,
};
