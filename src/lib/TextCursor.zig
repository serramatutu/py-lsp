//! Helper to consume chars from a string

const std = @import("std");
const assert = std.debug.assert;

const TextCursor = @This();

text: []const u8,
pos: usize,

pub const Error = error{Eof};

pub fn init(text: []const u8) TextCursor {
    return TextCursor{
        .text = text,
        .pos = 0,
    };
}

/// get the current token
pub inline fn curr(self: *TextCursor) Error!u8 {
    if (self.eof()) {
        return Error.Eof;
    }
    return self.text[self.pos];
}

/// consume a char and return it
pub fn next(self: *TextCursor) Error!u8 {
    const pos = self.pos;
    try self.advance();
    return self.text[pos];
}

/// consume a char
pub fn advance(self: *TextCursor) Error!void {
    assert(self.pos <= self.text.len);
    if (self.eof()) {
        return Error.Eof;
    }
    self.pos += 1;
}

/// go back one char
pub fn back(self: *TextCursor) void {
    assert(self.pos > 0);
    self.pos -= 1;
}

/// whether the cursor is at the end
pub inline fn eof(self: TextCursor) bool {
    assert(self.pos <= self.text.len);
    return self.pos == self.text.len;
}

test "cursor next" {
    var cur = TextCursor.init("abc");
    try std.testing.expectEqual('a', cur.next());
    try std.testing.expectEqual('b', cur.next());
    try std.testing.expectEqual('c', cur.next());
    try std.testing.expectEqual(TextCursor.Error.Eof, cur.next());
}
