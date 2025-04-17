//! Python tokenizer
//! See reference: https://docs.python.org/3/reference/lexical_analysis.html
const std = @import("std");
const assert = std.debug.assert;
const FixedBufStr = @import("fixed_buf_str.zig").FixedBufStr;
const SnapshotTestSession = @import("snap.zig").SnapshotTestSession;

/// Helper to consume chars from a string
const TextCursor = struct {
    text: []const u8,
    pos: usize,

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
    start: usize,
    len: usize,
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

        // literals
        /// int literal
        li_int,
        /// float literal
        li_float,
        /// string literal ("aaa" or u"aaa")
        li_str,
        /// format string literal (f"aaa {my_var:.2f}")
        li_fstr,
        /// bytes literal (b"aaa")
        li_bytes,

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
        sm_lt,
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

        fn keyword(self: Kind) []const u8 {
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
            .ws_newline => "\\n",
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

    // whether we have seen the first non-whitespace char in this line
    // or if we're still in the whitespace portion at the beginning of it
    _line_begun: bool,

    pub const Error = error{Eof};

    pub fn init(text: []const u8) Tokenizer {
        return Tokenizer{
            .text = text,
            .cur = TextCursor.init(text),
            ._line_begun = false,
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

    inline fn _isIdentifierHead(c: u8) bool {
        return std.ascii.isAlphabetic(c) or c == '_';
    }

    inline fn _isIdentifierTail(c: u8) bool {
        return std.ascii.isAlphanumeric(c) or c == '_';
    }

    inline fn _isStrDelim(c: u8) bool {
        return c == '"' or c == '\'';
    }

    inline fn _isWhitespace(c: u8) bool {
        return c == ' ' or c == '\r';
    }

    inline fn _isWhitespaceOrNewline(c: u8) bool {
        return _isWhitespace(c) or c == '\n';
    }

    /// advance cursor until first occurrence of c or eof
    /// returns true if cursor is at c, false if eof
    fn _advanceUntil(self: *Tokenizer, c: u8) bool {
        while (self._head() != c) {
            self.cur.advance() catch break;
        }
        return self._head() == c;
    }

    /// advance cursor while the head is equal to c or at eof
    fn _advanceWhile(self: *Tokenizer, c: u8) void {
        while (self._head() == c) {
            self.cur.advance() catch break;
        }
    }

    /// advance cursor to the first non-whitespace char or eof
    fn _advanceWhitespace(self: *Tokenizer) void {
        while (_isWhitespace(self._head())) {
            self.cur.advance() catch break;
        }
    }

    /// advance cursor to the first non-digit and non-underscor char or eof
    ///
    /// NOTE: this will accept stuff like 1__0__0, which is invalid. This is for
    /// robustness purposes so that we can keep tokenizing, but it should be checked
    /// downstream at the parser level once we're casting integer literals to AST
    /// nodes
    fn _advanceDigitPart(self: *Tokenizer) void {
        while (std.ascii.isDigit(self._head()) or self._head() == '_') {
            self.cur.advance() catch break;
        }
    }

    /// Advance the cursor if the next token is the expected value (and we're not at eof), otherwise keep
    /// it where it is.
    ///
    /// Returns a Token.Kind depending on what it did.
    fn _advanceIfNextEquals(self: *Tokenizer, expect: u8, ok: Token.Kind, fallback: Token.Kind) Token.Kind {
        const v = self.cur.curr() catch return fallback;
        if (v == expect) {
            self.cur.advance() catch unreachable;
            return ok;
        }
        return fallback;
    }

    /// Advance the cursor for an operator that can be doubled and used at assignment like
    /// <, <<, <=, <<=
    /// *, **, *=, **=
    fn _advanceDoubleOperatorAssign(
        self: *Tokenizer,
        op: u8,
        one: Token.Kind,
        two: Token.Kind,
        oneeq: Token.Kind,
        twoeq: Token.Kind,
    ) Token.Kind {
        const r_oneeq = self._advanceIfNextEquals('=', oneeq, one);
        // if got <=
        if (r_oneeq == oneeq) return oneeq;

        const r_two = self._advanceIfNextEquals(op, two, one);
        // if got <
        if (r_two == one) return one;

        // either << or <<=
        return self._advanceIfNextEquals('=', twoeq, two);
    }

    inline fn _head(self: *Tokenizer) u8 {
        assert(!self.cur.eof());
        return self.text[self.cur.pos];
    }

    /// Assuming we're at the head of a string (" or '), advance until the end of the string
    /// and return the token. This works with multiline strings delimited by """ also
    ///
    /// start should usually be self.cur.pos, but it can be earlier for things like f-strings.
    fn _advanceStrLiteral(self: *Tokenizer, start: usize, kind: Token.Kind) Error!Token {
        assert(_isStrDelim(self._head()));

        const str_delim = self._head();

        self.cur.advance()
        // 'f"' at the end of the file
        catch return .{ .start = start, .len = self.cur.pos - start, .kind = .ud_nonsense };

        // ""
        var is_multiline = false;
        if (self._head() == str_delim) {
            self.cur.advance()
            // "" at the end of the file
            catch return .{ .start = start, .len = self.cur.pos - start, .kind = kind };

            // "" empty string literal
            if (self._head() != str_delim) {
                return .{ .start = start, .len = self.cur.pos - start, .kind = kind };
            }

            // """ multiline string
            is_multiline = true;
            self.cur.advance() catch return .{ .start = start, .len = self.cur.pos - start, .kind = .ud_nonsense };
        }

        var prev_was_escape = false;
        while (!self.cur.eof() and
            (self._head() != str_delim or prev_was_escape) and
            (self._head() != '\n' or is_multiline))
        {
            prev_was_escape = self._head() == '\\';
            self.cur.advance() catch break;
        }

        var eof = self.cur.eof();
        if (!eof) self.cur.advance() catch {
            eof = true;
        };
        if (!eof and is_multiline) self.cur.advance() catch {
            eof = true;
        };
        if (!eof and is_multiline) self.cur.advance() catch {
            eof = true;
        };

        return .{ .start = start, .len = self.cur.pos - start, .kind = if (!eof) kind else .ud_nonsense };
    }

    pub fn next(self: *Tokenizer) Error!Token {
        // ignore whitespace after the line has begun to avoid spamming since
        // we only need them at the beginning of the line to figure out indentation
        if (self._line_begun) self._advanceWhitespace();

        const start = self.cur.pos;
        const first_char = try self.cur.next();

        // identifiers and keywords (and f-strings)
        if (_isIdentifierHead(first_char)) {
            self._line_begun = true;

            while (_isIdentifierTail(self._head())) {
                self.cur.advance() catch unreachable;
                if (self.cur.eof()) break;
            }

            const id_len = self.cur.pos - start;
            const id_text = self.text[start .. start + id_len];

            // string literals f"abc", u"abc" and bytes literals b"abc"
            if (id_len == 1) switch (id_text[0]) {
                'f', 'b', 'u' => |str_lit_qualifier| {
                    // fstr/str/binary literal
                    if (_isStrDelim(self._head())) {
                        const kind: Token.Kind = switch (str_lit_qualifier) {
                            'u' => .li_str,
                            'f' => .li_fstr,
                            'b' => .li_bytes,
                            else => unreachable,
                        };
                        return self._advanceStrLiteral(start, kind);
                    }
                    // an identifier named f, b or u
                },
                else => {},
            };

            return .{ .start = start, .len = id_len, .kind = Tokenizer._identifierToTokenKind(id_text) };
        }

        // string literals with no prefix (f, b or u)
        if (_isStrDelim(first_char)) {
            self._line_begun = true;
            self.cur.back();
            return self._advanceStrLiteral(self.cur.pos, .li_str);
        }

        // numeric literals
        var is_float_literal = first_char == '.';
        if (is_float_literal or std.ascii.isDigit(first_char)) {
            self._advanceDigitPart();
            if (self.cur.eof()) {
                const len = self.cur.pos - start;
                // 123 or .123
                return .{
                    .start = start,
                    .len = len,
                    .kind = if (is_float_literal)
                        if (len == 1)
                            .sm_dot
                        else
                            .li_float
                    else
                        .li_int,
                };
            }

            if (!is_float_literal and self._head() == '.') {
                is_float_literal = true;

                // 123.
                self.cur.advance() catch return .{
                    .start = start,
                    .len = self.cur.pos - start,
                    .kind = .li_float,
                };

                self._advanceDigitPart();
                if (self.cur.eof()) {
                    // 1.23 or 123.
                    return Token{
                        .start = start,
                        .len = self.cur.pos - start,
                        .kind = .li_float,
                    };
                }
            }

            if (self._head() == 'e' or self._head() == 'E') {
                is_float_literal = true;

                self.cur.advance() catch return .{ .start = start, .len = self.cur.pos - start, .kind = .ud_nonsense };

                if (self._head() == '-' or self._head() == '+') {
                    self.cur.advance() catch return .{ .start = start, .len = self.cur.pos - start, .kind = .ud_nonsense };
                }

                self._advanceDigitPart();
            }

            const len = self.cur.pos - start;
            const kind: Token.Kind =
                if (is_float_literal)
                    if (len == 1)
                        .sm_dot
                    else
                        .li_float
                else
                    .li_int;

            // if is_float_literal: 1e23, 1e-23, 1.2e34, .1e+23, 1.e+23, 123.
            // else: 123
            return .{ .start = start, .len = len, .kind = kind };
        }

        // symbols
        const kind: Token.Kind = switch (first_char) {
            // Newlines, whitespace and comments
            '\r' => self._advanceIfNextEquals('\n', .ws_newline, .ws_newline), // Windows/MacOS \n
            '\n' => .ws_newline, // Linux: \n
            '\t', ' ' => ws: {
                assert(!self._line_begun);
                self._advanceWhitespace();
                break :ws .ws_whitespace;
            },
            '\\' => .ws_linejoin,
            '#' => comment: {
                // TODO: type-ignore comments as different token type
                _ = self._advanceUntil('\n');
                break :comment .ud_comment;
            },

            // Operators that can be followed by a '='
            '=' => self._advanceIfNextEquals('=', .sm_twoeq, .sm_eq),
            '+' => self._advanceIfNextEquals('=', .sm_pluseq, .sm_plus),
            '-' => minus: {
                const minuseq = self._advanceIfNextEquals('=', .sm_minuseq, .sm_minus);
                if (minuseq == .sm_minuseq) break :minus .sm_minuseq;
                // -> arrow
                break :minus self._advanceIfNextEquals('>', .sm_arrow, .sm_minus);
            },
            '@' => self._advanceIfNextEquals('=', .sm_ateq, .sm_at),
            '%' => self._advanceIfNextEquals('=', .sm_percenteq, .sm_percent),
            '&' => self._advanceIfNextEquals('=', .sm_ampersandeq, .sm_ampersand),
            '|' => self._advanceIfNextEquals('=', .sm_pipeeq, .sm_pipe),
            '^' => self._advanceIfNextEquals('=', .sm_hateq, .sm_hat),
            '!' => self._advanceIfNextEquals('=', .sm_neq, .sm_exclamation),

            // Operators that can be doubled and followed by '='
            '*' => self._advanceDoubleOperatorAssign('*', .sm_star, .sm_twostar, .sm_stareq, .sm_twostareq),
            '/' => self._advanceDoubleOperatorAssign('/', .sm_slash, .sm_twoslash, .sm_slasheq, .sm_twoslasheq),
            '<' => self._advanceDoubleOperatorAssign('<', .sm_lt, .sm_lshift, .sm_lte, .sm_lshifteq),
            '>' => self._advanceDoubleOperatorAssign('>', .sm_gt, .sm_rshift, .sm_gte, .sm_rshifteq),

            // Other symbols
            '~' => .sm_tilde,
            ':' => .sm_colon,
            ',' => .sm_comma,
            '{' => .sm_lbrace,
            '}' => .sm_rbrace,
            '[' => .sm_lbrack,
            ']' => .sm_rbrack,
            '(' => .sm_lparen,
            ')' => .sm_rparen,

            // dot should never be reached as it should be covered in the float
            // literal case above
            '.' => unreachable,

            // all else is nonsense
            else => .ud_nonsense,
        };

        self._line_begun = kind != .ws_newline;

        return .{ .start = start, .len = self.cur.pos - start, .kind = kind };
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
        var line_no: u16 = 1;
        var line_start: usize = 0;

        var tok = Tokenizer.init(input);

        var has_nonsense = false;
        while (tok.next()) |token| {
            try token.debugFmt(input, output_writer);
            _ = try output_writer.write("\n");

            switch (token.kind) {
                Token.Kind.ws_newline => {
                    const line_contents = input[line_start..token.start];
                    _ = try output_writer.print("#{d}: {s}\n\n", .{ line_no, line_contents });
                    line_start = token.start + token.len;
                    line_no += 1;
                },
                Token.Kind.ud_nonsense => {
                    has_nonsense = true;
                },
                else => {},
            }
        } else |_| {
            // eof
        }

        try session.submitResult(output.slice(),
            // TODO: add header to test files which contain nonsense
            // For now all tests are valid (i.e parseable) python files
            if (has_nonsense) error.UnexpectedNonsense else null);
    }

    try session.assertOk();
}
