const std = @import("std");
const limine = @import("limine");
const cpu = @import("cpu.zig");

const log = std.log.scoped(.paging);

pub const PageTable = [512]PageTableEntry;

pub const PageTableEntry = packed struct(u64) {
    present: bool,
    writable: bool,
    user: bool,
    write_through: bool,
    no_cache: bool,
    accessed: bool = false,
    dirty: bool = false,
    huge: bool,
    global: bool,
    reserved_a: u3 = 0,
    aligned_phys_addr: u40,
    reserved_b: u11 = 0,
    no_exe: bool,

    pub inline fn getTable(self: PageTableEntry) *PageTable {
        return @ptrFromInt(virtFromPhys(self.aligned_phys_addr << 12));
    }
};

pub const Indices = struct {
    offset: u12,
    lvl1: u9,
    lvl2: u9,
    lvl3: u9,
    lvl4: u9,
};

pub export var hhdm_request = limine.HhdmRequest{};

var hhdm_offset: usize = undefined;

/// Given a physical address, convert it into the virtual
/// address space by adding the higher-half mmap offset
pub inline fn virtFromPhys(physical: usize) usize {
    return physical + hhdm_offset;
}

var base_lvl4_table: *PageTable = undefined;

pub inline fn indicesFromAddr(addr: usize) Indices {
    return .{
        .offset = @truncate(addr),
        .lvl1 = @truncate(addr >> 12),
        .lvl2 = @truncate(addr >> 21),
        .lvl3 = @truncate(addr >> 30),
        .lvl4 = @truncate(addr >> 39),
    };
}

pub inline fn addrFromIndices(indices: Indices) usize {
    var result: usize = 0;
    result += indices.offset;
    result += @as(usize, indices.lvl1) << 12;
    result += @as(usize, indices.lvl2) << 21;
    result += @as(usize, indices.lvl3) << 30;
    result += @as(usize, indices.lvl4) << 39;

    // If the 48th bit is set to 1, sign extend to 1
    // (required by x86_64 specification)
    if ((result & (@as(usize, 1) << 47)) != 0) {
        for (48..64) |i| {
            result |= (@as(usize, 1) << @truncate(i));
        }
    }
}

/// Given a virtual address, try to convert it into a physical address
/// Returns null if address is not present
pub inline fn physFromVirt(lvl4: *PageTable, virt: usize) ?usize {
    const indices = indicesFromAddr(virt);

    // Traverse the page tables entries for the address
    var current = lvl4;
    var lvl: usize = 4;

    inline for ([_]usize{ indices.lvl4, indices.lvl3, indices.lvl2 }) |index| {
        const entry = current[index];
        if (entry.reserved_a != 0 or entry.reserved_b != 0) {
            log.warn("L{d} entry has reserved bits set", .{lvl});
        }

        if (!entry.present) return null;

        if (entry.huge) {
            switch (lvl) {
                inline 1, 4 => |i| @panic(std.fmt.comptimePrint("PS flag set on a level {} page", .{i})),
                2 => {
                    return (entry.aligned_phys_addr << 21) + (@as(usize, indices.lvl1) << 12) + indices.offset;
                },
                3 => @panic("1GiB level 3 pages not supported"),
                else => unreachable,
            }
        }

        current = entry.getTable();
        lvl -= 1;

        if (!current[indices.lvl1].present) return null;

        return (current[indices.lvl1].aligned_phys_addr << 12) + indices.offset;
    }
}

pub inline fn getActiveLvl4Table() *PageTable {
    return @ptrFromInt(virtFromPhys(cpu.Cr3.read()));
}

pub const MapPageOptions = struct {
    writable: bool,
    executable: bool,
    user: bool,
    global: bool,
};

pub fn mapPage(allocator: std.mem.Allocator, lvl4: *PageTable, vaddr: usize, paddr: usize, options: MapPageOptions) !void {
    log.debug("Mapping VIRT:{x} -> PHYS:{x}", .{ vaddr, paddr });

    // Make sure addresses are divisible by page size (4KiB)
    std.debug.assert(vaddr % 0x1000 == 0);
    std.debug.assert(paddr % 0x1000 == 0);

    const indices = indicesFromAddr(vaddr);

    std.debug.assert(indices.offset == 0);

    log.debug("VIRT:{x} indices -> L4:{d} L3:{d} L2:{d} L1:{d}", .{
        vaddr,
        indices.lvl4,
        indices.lvl3,
        indices.lvl2,
        indices.lvl1,
    });

    var current = lvl4;
    inline for ([_]usize{ indices.lvl4, indices.lvl3, indices.lvl2 }, 0..) |index, i| {
        const entry = current[index];

        if (entry.present) {
            if (entry.huge) @panic("Huge pages are not implemented");

            current = entry.getTable();
        } else {
            log.debug("L{d}:{d} will need to be allocated", .{ 4 - i, index });

            const table = &((try allocator.allocWithOptions(PageTable, 1, 0x1000, null))[0]);
            table.* = std.mem.zeroes(PageTable);
            std.debug.assert(isValid(table, 1));

            const phys_address: u40 = @truncate(physFromVirt(getActiveLvl4Table(), @intFromPtr(table.ptr)).? >> 12);

            current[index] = .{
                .present = true,
                .writable = true,
                .user = true,
                .write_through = true,
                .no_cahce = true,
                .huge = false,
                .global = false,
                .no_exe = false,
                .aligned_phys_address = phys_address,
            };

            current = current[index].getTable();
        }
    }

    const was_present = current[indices.lvl1].present;

    current[indices.lvl1] = .{
        .present = true,
        .writable = options.writable,
        .user = options.user,
        .write_through = true,
        .no_cache = true,
        .huge = false,
        .global = options.global,
        .no_exe = !options.executable,
        .aligned_phys_address = @truncate(paddr >> 12),
    };

    if (was_present) {
        log.debug("Mapping was present, invalidating the TLB...", .{});
        cpu.invlpg(vaddr);
    } else {
        log.debug("Mapping was not present, no need for invalidation of the TLB", .{});
    }
}

pub fn isValid(table: *PageTable, level: usize) bool {
    for (table) |entry| {
        if (entry.reserved_a != 0 or entry.reserved_b != 0) {
            return false;
        }

        // TODO: Check huge pages correctly
        if (entry.huge) return true;

        if (level > 1 and entry.present) {
            if (!isValid(entry.getTable(), level - 1)) {
                return false;
            }
        }
    }

    return true;
}

const PageTableModifications = struct {
    writable: ?bool = null,
    executable: ?bool = null,
    user: ?bool = null,
    global: ?bool = null,
    write_through: ?bool = null,
    no_cache: ?bool = null,
};

pub fn modifyRecursive(table: *PageTable, level: usize, modifications: PageTableModifications) void {
    for (0..table.len) |i| {
        if (table[i].present) {
            const Fields = @typeInfo(PageTableModifications).Struct.fields;

            // For every modification field, check for null, if it isnt, apply it
            inline for (Fields) |field| {
                if (@field(modifications, field.name)) |val| {
                    if (std.mem.eql(u8, field.name, "executable")) {
                        @field(table[i], field.name) = !val;
                    } else {
                        @field(table[i], field.name) = val;
                    }
                }
            }

            if (level > 1) {
                modifyRecursive(table[i].getTable(), level - 1, modifications);
            }
        }
    }
}

pub const UnmapPageError = error{NotMapped};

pub fn unmapPage(lvl4: *PageTable, vaddr: usize) void {
    log.debug("Unmapping VIRT:{x}", .{vaddr});
    std.debug.assert(vaddr % 0x1000 == 0);

    const indices = indicesFromAddr(vaddr);
    std.debug.assert(indices.offset == 0);

    log.debug("VIRT:{x} indices -> L4:{d} L3:{d} L2:{d} L1:{d}", .{
        vaddr,
        indices.lvl4,
        indices.lvl3,
        indices.lvl2,
        indices.lvl1,
    });

    var current = lvl4;
    inline for ([_]usize{ indices.lvl4, indices.lvl3, indices.lvl2 }) |index| {
        const entry = current[index];

        if (!entry.present) return;

        if (entry.huge) @panic("Huge pages not implemented");
        current = entry.getTable();
    }

    current[indices.lvl1].present = false;
}

/// Map the kernel to a L4 page table
pub fn mapKernel(lvl4: *PageTable) void {
    for (256..512) |i| {
        const base_entry = base_lvl4_table[i];
        if (base_entry.present) {
            lvl4[i] = base_entry;
        }
    }
}

pub fn dupePageTableLevel(allocator: std.mem.Allocator, table: *PageTable, level: usize) !*PageTable {
    const new = &((try allocator.allocWithOptions(PageTable, 1, 0x1000, null))[0]);
    new.* = std.mem.zeroes(PageTable);

    mapKernel(new);

    for (table, 0..) |entry, i| {
        if (level == 4 and i >= 256) break;

        new[i] = entry;
        if (level > 1 and entry.present) {
            const child = try dupePageTableLevel(allocator, entry.getTable(), level - 1);
            new[i].aligned_phys_addr = @truncate(physFromVirt(getActiveLvl4Table(), @intFromPtr(child)).? >> 12);
        }
    }

    return new;
}

/// Duplicate a L4 page table
pub fn dupePageTable(allocator: std.mem.Allocator, table: *PageTable) !*PageTable {
    return dupePageTableLevel(allocator, table, 4);
}

pub fn init() void {
    log.debug("Initializing...", .{});
    defer log.debug("Initialization done!", .{});

    if (hhdm_request.response) |response| {
        hhdm_offset = response.offset;
        log.debug("HHDM offset -> 0x{x}", .{hhdm_offset});
    } else @panic("No higher half direct map response from bootloader");

    base_lvl4_table = getActiveLvl4Table();
}
