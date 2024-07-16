const gdt = @import("gdt.zig");

pub inline fn halt() noreturn {
    while (true) hlt();
}

pub inline fn hlt() void {
    asm volatile ("hlt");
}

pub inline fn cli() void {
    asm volatile ("cli");
}

pub inline fn sti() void {
    asm volatile ("sti");
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

pub inline fn inb(port: u16) u8 {
    return asm volatile ("inb %[port], %[result]"
        : [result] "={al}" (-> u8),
        : [port] "{dx}" (port),
    );
}

pub inline fn inw(port: u16) u16 {
    return asm volatile ("inw %[port], %[result]"
        : [result] "={ax}" (-> u16),
        : [port] "{dx}" (port),
    );
}

pub inline fn inl(port: u16) u32 {
    return asm volatile ("inl %[port], %[result]"
        : [result] "={eax}" (-> u32),
        : [port] "{dx}" (port),
    );
}

pub inline fn outb(port: u16, data: u8) void {
    asm volatile ("outb %[data], %[port]"
        :
        : [data] "{al}" (data),
          [port] "{dx}" (port),
    );
}

pub inline fn outw(port: u16, data: u16) void {
    asm volatile ("outw %[data], %[port]"
        :
        : [data] "{ax}" (data),
          [port] "{dx}" (port),
    );
}

pub inline fn outl(port: u16, data: u32) void {
    asm volatile ("outl %[data], %[port]"
        :
        : [data] "{eax}" (data),
          [port] "{dx}" (port),
    );
}

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
