const limine = @import("limine");

export var hddm_request: limine.HhdmRequest = .{};

pub var hddm_offset: usize = undefined;

pub inline fn virtualFromPhysical(physical: u64) u64 {
    return physical + hddm_offset;
}

pub fn init() void {
    const maybe_hddm_response = hddm_request.response;

    if (maybe_hddm_response == null) {
        @panic("Couldn't get bootloader information about the higher half kernel");
    }

    const hddm_response = maybe_hddm_response.?;

    hddm_offset = hddm_response.offset;
}
