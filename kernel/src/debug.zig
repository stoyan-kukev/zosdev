const std = @import("std");
const uart = @import("uart.zig");
const console = @import("console.zig");
const Color = @import("screen.zig").Color;

const console_settings = struct {
    const info: console.Settings = .{
        .background = Color.black,
        .foreground = Color.white,
    };

    const debug: console.Settings = .{
        .background = Color.black,
        .foreground = Color.yellow,
    };

    const err: console.Settings = .{
        .background = Color.black,
        .foreground = Color.red,
    };

    const warn: console.Settings = .{
        .background = Color.black,
        .foreground = Color.light_red,
    };
};

pub fn logFn(comptime level: std.log.Level, comptime scope: @Type(.EnumLiteral), comptime fmt: []const u8, args: anytype) void {
    const prefix = std.fmt.comptimePrint("[{s}] ({s}) ", .{ @tagName(level), @tagName(scope) });

    console.settings = @field(console_settings, @tagName(level));

    std.fmt.format(console.writer.any(), prefix ++ fmt ++ "\n", args) catch unreachable;
}
