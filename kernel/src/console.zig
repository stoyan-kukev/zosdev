const std = @import("std");

const arch = @import("arch.zig");
const screen = @import("screen.zig");
const Color = screen.Color;

const SpinLock = @import("common/SpinLock.zig");

var mutex: SpinLock = .{};

const Font = struct {
    data: []const u8,
    text_width: usize,
    text_height: usize,

    fn getBit(self: *const Font, x: usize, y: usize) bool {
        return (self.data[y] & std.math.pow(u8, 2, @intCast(x))) != 0;
    }

    fn getBytes(self: *const Font, location: usize) []const u8 {
        return self.data[location .. location + self.text_height];
    }
};

const font: Font = .{
    .data = @embedFile("fonts/vga8x16.bin"),
    .text_width = 8,
    .text_height = 16,
};

pub const Settings = struct {
    background: Color = Color.black,
    foreground: Color = Color.white,
};

const State = struct {
    width: usize = 0,
    height: usize = 0,
    x: usize = 0,
    y: usize = 0,
};

var state: State = .{};
pub var settings: Settings = .{};

pub fn clear() void {
    mutex.lock();
    defer mutex.unlock();

    for (0..screen.framebuffer.height) |y| {
        for (0..screen.framebuffer.width) |x| {
            screen.get(x, y).* = settings.background;
        }
    }

    state.x = 0;
    state.y = 0;
}

pub const Writer = std.io.Writer(void, error{}, printImpl);
pub const writer = Writer{ .context = {} };

pub fn print(comptime format: []const u8, arguments: anytype) void {
    mutex.lock();
    defer mutex.unlock();

    std.fmt.format(writer, format, arguments) catch arch.hang();
}

fn printImpl(_: void, bytes: []const u8) !usize {
    for (bytes) |byte| {
        printByte(byte);
    }

    return bytes.len;
}

fn printByte(byte: u8) void {
    if (!std.ascii.isASCII(byte)) {
        printFontBytes(getFontBytes(font.data.len - 2 * 16));
    } else if (byte != '\n') {
        printFontBytes(getFontBytes(@mod(byte * font.text_height, font.data.len)));
    }

    if (state.x + 1 >= state.width or byte == '\n') {
        printNewLine();
    } else {
        state.x += 1;
    }
}

fn printNewLine() void {
    state.x = 0;
    state.y += 1;

    if (state.y >= state.height) {
        mutex.unlock();
        clear();
        mutex.lock();

        state.y = 0;
    }
}

fn getFontBit(x: usize, y: usize, font_bytes: []const u8) bool {
    return (font_bytes[y] & std.math.pow(u8, 2, @intCast(x))) != 0;
}

fn getFontBytes(location: usize) []const u8 {
    return font.data[location .. location + font.text_height];
}

fn printFontBytes(font_bytes: []const u8) void {
    const x = state.x * font.text_width;
    const y = state.y * font.text_height;

    for (0..font.text_height) |dy| {
        for (0..font.text_width) |dx| {
            const font_bit = getFontBit(font.text_width - 1 - dx, dy, font_bytes);

            if (font_bit) {
                screen.get(x + dx, y + dy).* = settings.foreground;
            } else {
                screen.get(x + dx, y + dy).* = settings.background;
            }
        }
    }
}

pub fn init() void {
    state.width = @divFloor(screen.framebuffer.width, font.text_width);
    state.height = @divFloor(screen.framebuffer.height, font.text_height);

    clear();
}
