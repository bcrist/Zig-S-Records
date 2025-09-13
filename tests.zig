test "pretty=false" {
    const binary = "abcdef123\x00\x10\x01asdf\r\n0\x00";

    var buf: [1024]u8 = undefined;
    var w = std.io.Writer.fixed(&buf);

    var writer = try srec.writer(u32, &w, .{
        .header_data = "srec test",
        .line_ending = "\n"
    });

    try writer.write(0x1234567, binary);
    try writer.finish(0xABCD);

    try std.testing.expectEqualStrings(
        \\S00C000073726563207465737466
        \\S31701234567616263646566313233001001617364660D0A300037
        \\S5030002FA
        \\S7030000ABCD84
        \\
        , w.buffered());
}

test "pretty=true" {
    const binary = "abcdef123\x00\x10\x01asdf\r\n0\x00";

    var buf: [1024]u8 = undefined;
    var w = std.io.Writer.fixed(&buf);

    var writer = try srec.writer(u32, &w, .{
        .header_data = "srec test",
        .line_ending = "\n",
        .pretty = true,
    });

    try writer.write(0x1234567, binary);
    try writer.finish(0xABCD);

    try std.testing.expectEqualStrings(
        \\S0 0C 0000 737265632074657374 66
        \\S3 17 01234567 616263646566313233001001617364660D0A3000 37
        \\S5 03 0002  FA
        \\S7 03 0000ABCD  84
        \\
        , w.buffered());
}

const srec = @import("srec");
const std = @import("std");
