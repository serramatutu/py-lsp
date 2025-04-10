const std = @import("std");
const token = @import("token.zig");

pub fn main() !void {
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    const eof = token.TokenKind.Eof;
    if (eof == token.TokenKind.Eof) {
        stdout.print("hey");
    }

    try stdout.print("Run `zig build test` to run the tests.\n", .{});
    try bw.flush();
}
