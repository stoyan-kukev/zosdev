const limine = @import("limine");

const arch = @import("arch.zig");

export var framebuffer_request: limine.FramebufferRequest = .{};

pub var framebuffers: []*limine.Framebuffer = undefined;
pub var framebuffer: *limine.Framebuffer = undefined;

pub const Color = packed struct(u32) {
    b: u8,
    g: u8,
    r: u8,
    padding: u8 = 0,

    pub const white: Color = .{ .r = 255, .g = 255, .b = 255 };
    pub const black: Color = .{ .r = 0, .g = 0, .b = 0 };
    pub const red: Color = .{ .r = 255, .g = 0, .b = 0 };
    pub const blue: Color = .{ .r = 0, .g = 0, .b = 255 };
    pub const green: Color = .{ .r = 0, .g = 255, .b = 0 };
    pub const yellow: Color = .{ .r = 255, .g = 255, .b = 0 };
    pub const magenta: Color = .{ .r = 255, .g = 0, .b = 255 };
    pub const cyan: Color = .{ .r = 0, .g = 255, .b = 255 };
    pub const brown: Color = .{ .r = 165, .g = 42, .b = 42 };
    pub const light_gray: Color = .{ .r = 192, .g = 192, .b = 192 };
    pub const dark_gray: Color = .{ .r = 128, .g = 128, .b = 128 };
    pub const light_blue: Color = .{ .r = 173, .g = 216, .b = 230 };
    pub const light_green: Color = .{ .r = 144, .g = 238, .b = 144 };
    pub const light_cyan: Color = .{ .r = 224, .g = 255, .b = 255 };
    pub const light_red: Color = .{ .r = 255, .g = 182, .b = 193 };
    pub const light_magenta: Color = .{ .r = 255, .g = 20, .b = 147 };
};

pub fn get(x: u64, y: u64) *Color {
    const pixel_size = @sizeOf(Color);
    const pixel_offset = x * pixel_size + y * framebuffer.pitch;

    return @ptrCast(@alignCast(framebuffer.address + pixel_offset));
}

pub fn init() void {
    const maybe_framebuffer = framebuffer_request.response;

    if (maybe_framebuffer == null or maybe_framebuffer.?.framebuffers().len == 0) {
        arch.cpu.hang();
    }

    const framebuffer_response = maybe_framebuffer.?;

    framebuffers = framebuffer_response.framebuffers();
    framebuffer = framebuffers[0];
}
