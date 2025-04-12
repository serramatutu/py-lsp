//! Python tokenizer
//! See reference: https://docs.python.org/3/reference/lexical_analysis.html
const std = @import("std");
const assert = std.debug.assert;
const FixedBufStr = @import("fixed_buf_str.zig").FixedBufStr;
const SnapshotTestSession = @import("snap.zig").SnapshotTestSession;

/// Helper to consume chars from a string
const TextCursor = struct {
    text: []const u8,
    pos: u8,

    pub const Error = error{Eof};

    fn init(text: []const u8) TextCursor {
        return TextCursor{
            .text = text,
            .pos = 0,
        };
    }

    /// get the current token
    inline fn curr(self: *TextCursor) Error!u8 {
        if (self.eof()) {
            return Error.Eof;
        }
        return self.text[self.pos];
    }

    /// consume a char and return it
    fn next(self: *TextCursor) Error!u8 {
        const pos = self.pos;
        try self.advance();
        return self.text[pos];
    }

    /// consume a char
    fn advance(self: *TextCursor) Error!void {
        assert(self.pos <= self.text.len);
        if (self.eof()) {
            return Error.Eof;
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
    var cur = TextCursor.init("abc");
    try std.testing.expectEqual('a', cur.next());
    try std.testing.expectEqual('b', cur.next());
    try std.testing.expectEqual('c', cur.next());
    try std.testing.expectEqual(TextCursor.Error.Eof, cur.next());
}

pub const Token = struct {
    start: u32,
    len: u32,
    kind: Kind,

    pub const Kind = enum {
        // keywords
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

        // user-defined
        /// # a python comment
        ud_comment,
        /// an identifier like a variable name, module name or function name
        ud_identifier,
        /// any nonsense the user writes that does not match any other token type
        ud_nonsense,

        // symbols
        /// &
        sm_ampersand,
        /// &=
        sm_ampersandeq,
        /// ->
        sm_arrow,
        /// @
        sm_at,
        /// @=
        sm_ateq,
        /// :
        sm_colon,
        /// :=
        sm_coloneq,
        /// ,
        sm_comma,
        /// .
        sm_dot,
        /// ...
        sm_ellipsis,
        /// =
        sm_eq,
        /// !
        sm_exclamation,
        /// >
        sm_gt,
        /// >=
        sm_gte,
        /// ^
        sm_hat,
        /// ^=
        sm_hateq,
        /// {
        sm_lbrace,
        /// [
        sm_lbrack,
        /// <
        sm_le,
        /// )
        sm_lparen,
        /// <<
        sm_lshift,
        /// <<=
        sm_lshifteq,
        /// <=
        sm_lte,
        /// -
        sm_minus,
        /// -=
        sm_minuseq,
        /// !=
        sm_neq,
        /// %
        sm_percent,
        /// %=
        sm_percenteq,
        /// |
        sm_pipe,
        /// |=
        sm_pipeeq,
        /// +
        sm_plus,
        /// +=
        sm_pluseq,
        /// }
        sm_rbrace,
        /// ]
        sm_rbrack,
        /// )
        sm_rparen,
        /// >>
        sm_rshift,
        /// >>=
        sm_rshifteq,
        /// ;
        sm_semicolon,
        /// /
        sm_slash,
        /// /=
        sm_slasheq,
        /// *
        sm_star,
        /// *=
        sm_stareq,
        /// ~
        sm_tilde,
        /// ==
        sm_twoeq,
        /// //
        sm_twoslash,
        /// //=
        sm_twoslasheq,
        /// **
        sm_twostar,
        /// **=
        sm_twostareq,

        // whitespace
        /// \
        ws_linejoin,
        /// \n, \r\n or \r
        ws_newline,
        /// any sequence of '\n', '\r' or ' '
        ws_whitespace,

        fn keyword(self: Token.Kind) []const u8 {
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

    /// pretty-print self onto the writer
    pub fn debugFmt(self: Token, source: []const u8, writer: anytype) !void {
        const text = switch (self.kind) {
            Kind.ws_newline => "\\n",
            else => source[self.start .. self.start + self.len],
        };
        try writer.print(
            "Token(kind={s}, text=\"{s}\", start={}, len={})",
            .{ @tagName(self.kind), text, self.start, self.len },
        );
    }
};

/// Tokenizer for Python code
pub const Tokenizer = struct {
    text: []const u8,
    cur: TextCursor,

    pub const Error = error{Eof};

    pub fn init(text: []const u8) Tokenizer {
        return Tokenizer{
            .text = text,
            .cur = TextCursor.init(text),
        };
    }

    /// Convert an identifier string to Token.Kind.
    /// This assumes the Token.Kind won't be Nonsense
    fn _identifierToTokenKind(str: []const u8) Token.Kind {
        assert(str.len > 0);
        inline for (comptime std.enums.values(Token.Kind)) |val| {
            if (std.mem.eql(u8, val.keyword(), str)) {
                return val;
            }
        }
        return Token.Kind.ud_identifier;
    }

    fn _isIdentifierHead(c: u8) bool {
        return std.ascii.isAlphabetic(c) or c == '_';
    }

    fn _isIdentifierTail(c: u8) bool {
        return std.ascii.isAlphanumeric(c) or c == '_';
    }

    pub fn next(self: *Tokenizer) Error!Token {
        const start = self.cur.pos;
        const first_char = try self.cur.next();

        // identifiers and keywords
        if (Tokenizer._isIdentifierHead(first_char)) {
            while (Tokenizer._isIdentifierTail(self.text[self.cur.pos])) {
                self.cur.advance() catch unreachable;
                if (self.cur.eof()) break;
            }

            const len = self.cur.pos - start;
            return Token{ .start = start, .len = len, .kind = Tokenizer._identifierToTokenKind(self.text[start .. start + len]) };
        }

        const kind = switch (first_char) {
            // Newlines, whitespace and comments
            '\r' => cr: {
                const n = self.cur.curr() catch break :cr Token.Kind.ws_newline;
                if (n == '\n') {
                    self.cur.advance() catch unreachable;
                    // Windows: CRLF
                    break :cr Token.Kind.ws_newline;
                }

                // MacOS: CR
                break :cr Token.Kind.ws_newline;
            },
            '\n' => Token.Kind.ws_newline, // Linux: \n
            '\t', ' ' => Token.Kind.ws_whitespace,
            '\\' => Token.Kind.ws_linejoin,
            '#' => comment: {
                // TODO: type-ignore comments
                while (self.text[self.cur.pos] != '\n') {
                    self.cur.advance() catch break;
                }
                break :comment Token.Kind.ud_comment;
            },

            // Symbols
            '+' => plus: {
                const v = self.cur.curr() catch break :plus Token.Kind.sm_plus;
                if (v == '=') {
                    self.cur.advance() catch unreachable;
                    break :plus Token.Kind.sm_pluseq;
                }
                break :plus Token.Kind.sm_plus;
            },

            else => Token.Kind.ud_nonsense,
        };
        return Token{ .start = start, .len = self.cur.pos - start, .kind = kind };
    }
};

test "_identifierToToken.Kind" {
    try std.testing.expectEqual(Token.Kind.kw_while, Tokenizer._identifierToTokenKind("while"));
    try std.testing.expectEqual(Token.Kind.kw_false, Tokenizer._identifierToTokenKind("False"));
    try std.testing.expectEqual(Token.Kind.ud_identifier, Tokenizer._identifierToTokenKind("myId123"));
}

test "compare snapshots" {
    var session = try SnapshotTestSession.init(std.testing.allocator, "tok");
    defer session.deinit();

    var output = try FixedBufStr.init(std.testing.allocator, SnapshotTestSession.EXPECT_CAP);
    defer output.deinit();
    const output_writer = output.writer();

    while (try session.next()) |input| {
        var tok = Tokenizer.init(input);

        while (tok.next()) |token| {
            try token.debugFmt(input, output_writer);
            _ = try output_writer.write("\n");
        } else |_| {}

        try session.submitResult(output.slice());
    }
}

test "eof" {
    var tok = Tokenizer.init("");
    try std.testing.expectEqual(Tokenizer.Error.Eof, tok.next());
}

test "keyword" {
    var tok = Tokenizer.init("False");
    try std.testing.expectEqual(Token{ .start = 0, .len = 5, .kind = Token.Kind.kw_false }, tok.next());
    try std.testing.expectEqual(Tokenizer.Error.Eof, tok.next());
}

test "keyword identifier" {
    var tok = Tokenizer.init("if _test1");
    try std.testing.expectEqual(Token{ .start = 0, .len = 2, .kind = Token.Kind.kw_if }, tok.next());
    try std.testing.expectEqual(Token{ .start = 2, .len = 1, .kind = Token.Kind.ws_whitespace }, tok.next());
    try std.testing.expectEqual(Token{ .start = 3, .len = 6, .kind = Token.Kind.ud_identifier }, tok.next());
    try std.testing.expectEqual(Tokenizer.Error.Eof, tok.next());
}

test "identifier LF identifier" {
    var tok = Tokenizer.init("line1\nline2");
    try std.testing.expectEqual(Token{ .start = 0, .len = 5, .kind = Token.Kind.ud_identifier }, tok.next());
    try std.testing.expectEqual(Token{ .start = 5, .len = 1, .kind = Token.Kind.ws_newline }, tok.next());
    try std.testing.expectEqual(Token{ .start = 6, .len = 5, .kind = Token.Kind.ud_identifier }, tok.next());
    try std.testing.expectEqual(Tokenizer.Error.Eof, tok.next());
}

test "identifier CRLF identifier" {
    var tok = Tokenizer.init("line1\r\nline2");
    try std.testing.expectEqual(Token{ .start = 0, .len = 5, .kind = Token.Kind.ud_identifier }, tok.next());
    try std.testing.expectEqual(Token{ .start = 5, .len = 2, .kind = Token.Kind.ws_newline }, tok.next());
    try std.testing.expectEqual(Token{ .start = 7, .len = 5, .kind = Token.Kind.ud_identifier }, tok.next());
    try std.testing.expectEqual(Tokenizer.Error.Eof, tok.next());
}

test "identifier CR identifier" {
    var tok = Tokenizer.init("line1\rline2");
    try std.testing.expectEqual(Token{ .start = 0, .len = 5, .kind = Token.Kind.ud_identifier }, tok.next());
    try std.testing.expectEqual(Token{ .start = 5, .len = 1, .kind = Token.Kind.ws_newline }, tok.next());
    try std.testing.expectEqual(Token{ .start = 6, .len = 5, .kind = Token.Kind.ud_identifier }, tok.next());
    try std.testing.expectEqual(Tokenizer.Error.Eof, tok.next());
}

test "comment" {
    var tok = Tokenizer.init("line1\n# this is a comment\nline2");
    try std.testing.expectEqual(Token{ .start = 0, .len = 5, .kind = Token.Kind.ud_identifier }, tok.next());
    try std.testing.expectEqual(Token{ .start = 5, .len = 1, .kind = Token.Kind.ws_newline }, tok.next());
    try std.testing.expectEqual(Token{ .start = 6, .len = 19, .kind = Token.Kind.ud_comment }, tok.next());
    try std.testing.expectEqual(Token{ .start = 25, .len = 1, .kind = Token.Kind.ws_newline }, tok.next());
    try std.testing.expectEqual(Token{ .start = 26, .len = 5, .kind = Token.Kind.ud_identifier }, tok.next());
    try std.testing.expectEqual(Tokenizer.Error.Eof, tok.next());
}
