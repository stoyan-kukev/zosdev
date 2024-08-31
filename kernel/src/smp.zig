const limine = @import("limine");

const arch = @import("arch.zig");

export var smp_request: limine.SmpRequest = .{};

pub const max_core_count = 255;
var core_info_buffer: [max_core_count]arch.cpu.core.Info = undefined;

pub var core_count: usize = undefined;
pub var bootstrap_lapic_id: u32 = undefined;

pub fn init(comptime jumpPoint: *const fn () noreturn) noreturn {
    const maybe_smp_response = smp_request.response;

    if (maybe_smp_response == null) {
        @panic("Couldn't get bootloader info for SMP");
    }

    const smp_response = maybe_smp_response.?;

    core_count = smp_response.cpu_count;

    if (arch.target.isX86()) {
        bootstrap_lapic_id = smp_response.bsp_lapic_id;
    }

    if (core_count > max_core_count) {
        @panic("The amount of cores exceeds the maximum amount");
    }

    arch.cpu.core.Info.write(&core_info_buffer[0]);

    const startCore = struct {
        pub fn lambda(raw_core_info: *limine.SmpInfo) callconv(.C) noreturn {
            arch.cpu.core.Info.write(&core_info_buffer[raw_core_info.processor_id]);

            jumpPoint();
        }
    }.lambda;

    // Iterate through all CPUs reported by the bootloader
    for (smp_response.cpus()) |raw_core_info| {
        // Store the processor ID in our core info buffer
        core_info_buffer[raw_core_info.processor_id].id = raw_core_info.processor_id;

        // For all cores except the bootstrap processor (BSP)
        if (raw_core_info.processor_id != 0) {
            // Set the entry point for the core to our startCore function
            // This is done atomically to ensure visibility across cores
            @atomicStore(@TypeOf(raw_core_info.goto_address), &raw_core_info.goto_address, &startCore, .monotonic);
        }
    }

    jumpPoint();
}
