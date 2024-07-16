const std = @import("std");
const limine = @import("limine");
const builtin = @import("builtin");
const debug = @import("debug.zig");
const uart = @import("uart.zig");
const log = std.log.scoped(.core);

pub const std_options = .{
    .logFn = debug.logFn,
    .log_level = switch (builtin.mode) {
        .Debug => .debug,
        else => .info,
    },
};

pub fn panic(msg: []const u8, error_return_trace: ?*std.builtin.StackTrace, ret_addr: ?usize) noreturn {
    _ = error_return_trace;
    _ = ret_addr;
    log.err("*Panic*\n{s}", .{msg});
    while (true) {}
}

export fn _start() callconv(.C) noreturn {
    init() catch |err| {
        log.err("Initialization failed: {}", .{err});
    };
    while (true) {}
}

pub export var framebuffer_request = limine.FramebufferRequest{};

// Only one additional buffer for double buffering
var back_buffer: [1920 * 1080 * 4]u8 align(8) = undefined;

fn clearBuffer(buffer: []u8) void {
    @memset(buffer, 0);
}

fn drawPixelToBuffer(buffer: []u8, pitch: usize, x: usize, y: usize, color: u32) void {
    if (x >= 1920 or y >= 1080) return;

    const offset = y * pitch + x * 4;
    const pixel_ptr: *align(1) u32 = @ptrCast(@alignCast(&buffer[offset]));
    pixel_ptr.* = color;
}

fn drawRectToBuffer(buffer: []u8, pitch: usize, x: usize, y: usize, width: usize, height: usize, color: u32) void {
    var dy: usize = 0;
    while (dy < height) : (dy += 1) {
        var dx: usize = 0;
        while (dx < width) : (dx += 1) {
            drawPixelToBuffer(buffer, pitch, x + dx, y + dy, color);
        }
    }
}

fn swapBuffers(backbuffer: []u8, framebuffer: *limine.Framebuffer) void {
    const fb_size = framebuffer.pitch * framebuffer.height;
    @memcpy(framebuffer.address[0..fb_size], backbuffer[0..fb_size]);
}

pub fn init() !void {
    uart.init(uart.Speed.fromBaudrate(9600).?);
    log.info("UART initialized!", .{});

    const response = framebuffer_request.response orelse {
        log.err("No framebuffer response, aborting!", .{});
        return error.NoFramebuffer;
    };

    if (response.framebuffer_count < 1) {
        log.err("No framebuffers found, aborting!", .{});
        return error.NoFramebuffer;
    }

    const framebuffer = response.framebuffers()[0];
    log.info("Video mode: {}x{}", .{ framebuffer.width, framebuffer.height });

    if (back_buffer.len < framebuffer.pitch * framebuffer.height) {
        log.err("Buffer size is too small for the current resolution", .{});
        return error.BufferTooSmall;
    }

    var frame: u64 = 0;

    while (true) {
        clearBuffer(&back_buffer);

        const base_y: u64 = 400;
        const amplitude: u64 = 200;
        const sin_value = @sin(@as(f64, @floatFromInt(frame)) * 0.05);
        const y_offset: u64 = @intFromFloat(@abs(sin_value) * @as(f64, amplitude));
        const y = if (sin_value >= 0)
            @min(base_y + y_offset, framebuffer.height - 1)
        else
            @max(base_y, y_offset) - y_offset;

        drawRectToBuffer(&back_buffer, framebuffer.pitch, 200, y, 100, 100, 0x00_3C_D5_07);

        swapBuffers(&back_buffer, framebuffer);

        frame += 1;

        var i: u64 = 0;
        while (i < 1_000_000) : (i += 1) {
            asm volatile ("" ::: "memory");
        }
    }
}
