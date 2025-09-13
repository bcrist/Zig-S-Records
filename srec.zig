pub fn writer(comptime Address: type, w: *std.io.Writer, options: Writer_Options) !Writer(Address) {
    return Writer(Address).init(w, options);
}

pub const Writer_Options = struct {
    line_ending: ?[]const u8 = null,
    header_data: []const u8 = "",
    pretty: bool = false,
};

pub fn Writer(comptime Address: type) type {
    switch (@typeInfo(Address).int.bits) {
        16, 24, 32 => {},
        else => @compileError("Invalid address type; must be u32, u24, or u16"),
    }

    return struct {
        inner: *std.io.Writer,
        data_rec_count: usize,
        line_ending: []const u8,
        pretty: bool,

        const Self = @This();

        pub fn init(w: *std.io.Writer, options: Writer_Options) !Self {
            var self = Self{
                .inner = w,
                .data_rec_count = 0,
                .line_ending = options.line_ending orelse default_line_ending(),
                .pretty = options.pretty,
            };
            try self.write_record('0', 0, options.header_data);
            return self;
        }

        fn write_byte(self: *Self, d: u8) !void {
            try self.inner.writeByte("0123456789ABCDEF"[d >> 4]);
            try self.inner.writeByte("0123456789ABCDEF"[@as(u4, @truncate(d))]);
        }

        fn write_record(self: *Self, record_type: u8, address: anytype, data: []const u8) !void {
            const A = @TypeOf(address);
            std.debug.assert(@bitSizeOf(A) <= 32);

            try self.inner.writeByte('S');
            try self.inner.writeByte(record_type);

            if (self.pretty) {
                try self.inner.writeByte(' ');
            }

            var checksum: u8 = @intCast(data.len + 3);
            try self.write_byte(checksum);

            if (self.pretty) {
                try self.inner.writeByte(' ');
            }

            if (comptime @bitSizeOf(A) > 24) {
                const address_part: u8 = @truncate(address >> 24);
                try self.write_byte(address_part);
                checksum +%= address_part;
            }
            if (comptime @bitSizeOf(A) > 16) {
                const address_part: u8 = @truncate(address >> 16);
                try self.write_byte(address_part);
                checksum +%= address_part;
            }

            const address_high: u8 = @truncate(address >> 8);
            try self.write_byte(address_high);
            checksum +%= address_high;

            const address_low: u8 = @truncate(address);
            try self.write_byte(address_low);
            checksum +%= address_low;

            if (self.pretty) {
                try self.inner.writeByte(' ');
            }

            for (data) |d| {
                try self.write_byte(d);
                checksum +%= d;
            }

            if (self.pretty) {
                try self.inner.writeByte(' ');
            }

            try self.write_byte(checksum ^ 0xFF);

            try self.inner.writeAll(self.line_ending);

            self.data_rec_count += 1;
        }

        pub fn write(self: *Self, address: Address, data: []const u8) !void {
            var start = address;
            var remaining = data;

            const data_record_type = switch(@bitSizeOf(Address)) {
                16 => '1',
                24 => '2',
                32 => '3',
                else => unreachable,
            };

            while (remaining.len > 32) {
                try self.write_record(data_record_type, start, remaining[0..32]);
                start += 32;
                remaining = remaining[32..];
            }

            try self.write_record(data_record_type, start, remaining);
        }

        pub fn finish(self: *Self, termination_address: Address) !void {
            if (self.data_rec_count <= 0xFFFF) {
                const count: u16 = @intCast(self.data_rec_count);
                try self.write_record('5', count, "");
            } else if (self.data_rec_count <= 0xFFFFFF) {
                const count: u24 = @intCast(self.data_rec_count);
                try self.write_record('6', count, "");
            }

            const termination_record_type = switch (@bitSizeOf(Address)) {
                16 => '9',
                24 => '8',
                32 => '7',
                else => unreachable,
            };
            try self.write_record(termination_record_type, termination_address, "");
        }
    };
}

fn default_line_ending() []const u8 {
    return if (@import("builtin").target.os.tag == .windows) "\r\n" else "\n";
}

const std = @import("std");
