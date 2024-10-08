const std = @import("std");

const cpu = @import("cpu.zig");
const higher_half = @import("../../higher_half.zig");
const smp = @import("../../smp.zig");

pub const Lapic = struct {
    base: usize = 0xffff_8000_fee0_0000,

    pub const Register = enum(u32) {
        eoi = 0x80,
        timer_lvt = 0x320,
        timer_init = 0x380,
    };

    pub fn write(self: Lapic, register: Register, value: u32) void {
        @as(*volatile u32, @ptrFromInt(self.base + @intFromEnum(register))).* = value;
    }

    pub fn read(self: Lapic, register: Register) u32 {
        return @as(*volatile u32, @ptrFromInt(self.base + @intFromEnum(register))).*;
    }

    pub fn oneshot(self: Lapic, vector: u8, ticks: u32) void {
        self.write(.timer_init, 0);
        self.write(.timer_lvt, @as(usize, 1) << 16);

        self.write(.timer_lvt, vector);
        self.write(.timer_init, ticks);
    }
};

var lapics: [smp.max_core_count]Lapic = .{.{}} ** smp.max_core_count;

pub fn getLapic() Lapic {
    return lapics[cpu.core.Info.read().id];
}

pub fn init() void {
    const core_id = cpu.core.Info.read().id;

    lapics[core_id].base = higher_half.virtualFromPhysical(cpu.registers.ModelSpecific.read(.apic_base) & 0xFFFF_F000);

    const @"11th_bit": u64 = 1 << 11;
    const lapic_enabled_value = cpu.registers.ModelSpecific.read(.apic_base) | @"11th_bit";
    cpu.registers.ModelSpecific.write(.apic_base, lapic_enabled_value);

    lapics[core_id].write(.timer_init, 0);
}
