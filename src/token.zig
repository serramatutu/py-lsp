//! Python tokenizer
const std = @import("std");
const assert = std.debug.assert;

pub const TokenizerError = error{
    Eof,
};

/// Helper to consume chars from a string
const TextCursor = struct {
    text: []const u8,
    pos: u8,

    fn new(text: []const u8) TextCursor {
        return TextCursor{
            .text = text,
            .pos = 0,
        };
    }

    /// get the current token
    inline fn curr(self: *TextCursor) TokenizerError!u8 {
        if (self.eof()) {
            return TokenizerError.Eof;
        }
        return self.text[self.pos];
    }

    /// consume a char and return it
    fn next(self: *TextCursor) TokenizerError!u8 {
        const pos = self.pos;
        try self.advance();
        return self.text[pos];
    }

    /// consume a char
    fn advance(self: *TextCursor) TokenizerError!void {
        assert(self.pos <= self.text.len);
        if (self.eof()) {
            return TokenizerError.Eof;
        }
        self.pos += 1;
    }

    /// go back one char
    fn back(self: *TextCursor) void {
        assert(self.pos > 0);
        self.pos -= 1;
    }

    /// whether the cursor is at the end
    inline fn eof(self: TextCursor) bool {
        assert(self.pos <= self.text.len);
        return self.pos == self.text.len;
    }
};

test "cursor next" {
    var cur = TextCursor.new("abc");
    try std.testing.expectEqual('a', cur.next());
    try std.testing.expectEqual('b', cur.next());
    try std.testing.expectEqual('c', cur.next());
    try std.testing.expectEqual(TokenizerError.Eof, cur.next());
}

pub const TokenKind = enum {
    kw_and,
    kw_as,
    kw_assert,
    kw_async,
    kw_await,
    kw_break,
    kw_class,
    kw_continue,
    kw_def,
    kw_del,
    kw_elif,
    kw_else,
    kw_except,
    kw_false,
    kw_finally,
    kw_for,
    kw_from,
    kw_global,
    kw_if,
    kw_import,
    kw_in,
    kw_is,
    kw_lambda,
    kw_none,
    kw_nonlocal,
    kw_not,
    kw_or,
    kw_pass,
    kw_raise,
    kw_return,
    kw_true,
    kw_try,
    kw_while,
    kw_with,
    kw_yield,

    ws_newline,
    ws_tab,
    ws_space,

    identifier,
    nonsense,

    fn keyword(self: TokenKind) []const u8 {
        return switch (self) {
            .kw_and => "and",
            .kw_as => "as",
            .kw_assert => "assert",
            .kw_async => "async",
            .kw_await => "await",
            .kw_break => "break",
            .kw_class => "class",
            .kw_continue => "continue",
            .kw_def => "def",
            .kw_del => "del",
            .kw_elif => "elif",
            .kw_else => "else",
            .kw_except => "except",
            .kw_false => "False",
            .kw_finally => "finally",
            .kw_for => "for",
            .kw_from => "from",
            .kw_global => "global",
            .kw_if => "if",
            .kw_import => "import",
            .kw_in => "in",
            .kw_is => "is",
            .kw_lambda => "lambda",
            .kw_none => "None",
            .kw_nonlocal => "nonlocal",
            .kw_not => "not",
            .kw_or => "or",
            .kw_pass => "pass",
            .kw_raise => "raise",
            .kw_return => "return",
            .kw_true => "True",
            .kw_try => "try",
            .kw_while => "while",
            .kw_with => "with",
            .kw_yield => "yield",
            else => "",
        };
    }
};

pub const Token = struct {
    start: u32,
    len: u32,
    kind: TokenKind,
};

/// Tokenizer for Python code
pub const Tokenizer = struct {
    text: []const u8,
    cur: TextCursor,

    pub fn new(text: []const u8) Tokenizer {
        return Tokenizer{
            .text = text,
            .cur = TextCursor.new(text),
        };
    }

    /// Convert an identifier string to TokenKind.
    /// This assumes the TokenKind won't be Nonsense
    fn _identifierToTokenKind(str: []const u8) TokenKind {
        assert(str.len > 0);
        inline for (comptime std.enums.values(TokenKind)) |val| {
            if (std.mem.eql(u8, val.keyword(), str)) {
                return val;
            }
        }
        return TokenKind.identifier;
    }

    fn _isIdentifierHead(c: u8) bool {
        return std.ascii.isAlphabetic(c) or c == '_';
    }

    fn _isIdentifierTail(c: u8) bool {
        return std.ascii.isAlphanumeric(c) or c == '_';
    }

    pub fn next(self: *Tokenizer) TokenizerError!Token {
        const start = self.cur.pos;
        const first_char = try self.cur.next();

        // identifiers
        if (Tokenizer._isIdentifierHead(first_char)) {
            while (Tokenizer._isIdentifierTail(self.text[self.cur.pos])) {
                self.cur.advance() catch unreachable;
                if (self.cur.eof()) break;
            }

            const len = self.cur.pos - start;
            return Token{ .start = start, .len = len, .kind = Tokenizer._identifierToTokenKind(self.text[start..len]) };
        }

        // TODO: \n on windows
        const kind = switch (first_char) {
            '\n' => TokenKind.ws_newline,
            '\t' => TokenKind.ws_tab,
            ' ' => TokenKind.ws_space,
            else => TokenKind.nonsense,
        };
        return Token{ .start = start, .len = 1, .kind = kind };
    }
};

test "eof" {
    var tok = Tokenizer.new("");
    try std.testing.expectEqual(TokenizerError.Eof, tok.next());
}

test "keyword" {
    var tok = Tokenizer.new("False");
    try std.testing.expectEqual(Token{ .start = 0, .len = 5, .kind = TokenKind.kw_false }, tok.next());
    try std.testing.expectEqual(TokenizerError.Eof, tok.next());
}

test "keyword identifier" {
    var tok = Tokenizer.new("if _test1");
    try std.testing.expectEqual(Token{ .start = 0, .len = 2, .kind = TokenKind.kw_if }, tok.next());
    try std.testing.expectEqual(Token{ .start = 2, .len = 1, .kind = TokenKind.ws_space }, tok.next());
    try std.testing.expectEqual(Token{ .start = 3, .len = 6, .kind = TokenKind.identifier }, tok.next());
    try std.testing.expectEqual(TokenizerError.Eof, tok.next());
}

test "_identifierToTokenKind" {
    try std.testing.expectEqual(TokenKind.kw_while, Tokenizer._identifierToTokenKind("while"));
    try std.testing.expectEqual(TokenKind.kw_false, Tokenizer._identifierToTokenKind("False"));
    try std.testing.expectEqual(TokenKind.identifier, Tokenizer._identifierToTokenKind("myId123"));
}
