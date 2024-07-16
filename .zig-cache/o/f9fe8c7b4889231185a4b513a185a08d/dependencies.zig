pub const packages = struct {
    pub const @"1220041424e7d68e00b2c8c84a56b0a34b51963383af39a425fa75fd27f553a1be23" = struct {
        pub const build_root = "/home/stoyankukev/.cache/zig/p/1220041424e7d68e00b2c8c84a56b0a34b51963383af39a425fa75fd27f553a1be23";
        pub const deps: []const struct { []const u8, []const u8 } = &.{};
    };
    pub const @"12206883f336b8b137741d1607e682c842204f33b48d5838555c04c6f03b164e4101" = struct {
        pub const build_root = "/home/stoyankukev/.cache/zig/p/12206883f336b8b137741d1607e682c842204f33b48d5838555c04c6f03b164e4101";
        pub const deps: []const struct { []const u8, []const u8 } = &.{};
    };
    pub const @"1220f946f839eab2ec49dca1c805ce72ac3e3ef9c47b3afcdecd1c05a7b35f66d277" = struct {
        pub const build_root = "/home/stoyankukev/.cache/zig/p/1220f946f839eab2ec49dca1c805ce72ac3e3ef9c47b3afcdecd1c05a7b35f66d277";
        pub const build_zig = @import("1220f946f839eab2ec49dca1c805ce72ac3e3ef9c47b3afcdecd1c05a7b35f66d277");
        pub const deps: []const struct { []const u8, []const u8 } = &.{};
    };
};

pub const root_deps: []const struct { []const u8, []const u8 } = &.{
    .{ "ovmf", "12206883f336b8b137741d1607e682c842204f33b48d5838555c04c6f03b164e4101" },
    .{ "limine", "1220041424e7d68e00b2c8c84a56b0a34b51963383af39a425fa75fd27f553a1be23" },
    .{ "limine_zig", "1220f946f839eab2ec49dca1c805ce72ac3e3ef9c47b3afcdecd1c05a7b35f66d277" },
};
