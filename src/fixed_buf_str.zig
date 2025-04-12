const std = @import("std");

// An abstraction for a string backed by a fixed buffer.
//
// It allocates the underlying buffer once during init(), and will never reallocate
// it again.
//
// Currently, it does not care about UTF-8 specifics.
pub const FixedBufStr = struct {
    buf: []u8,
    a: std.mem.Allocator,
    len: usize,

    pub const InitError = error{OutOfMemory};
    pub const WriteError = error{CapacityExceeded};

    pub const Writer = std.io.Writer(
        *FixedBufStr,
        WriteError,
        append,
    );

    pub fn writer(self: *FixedBufStr) Writer {
        return .{ .context = self };
    }

    pub fn init(a: std.mem.Allocator, cap: usize) InitError!FixedBufStr {
        std.debug.assert(cap > 0);
        return FixedBufStr{
            .buf = try a.alloc(u8, cap),
            .len = 0,
            .a = a,
        };
    }

    pub fn initWith(a: std.mem.Allocator, content: []const u8) InitError!FixedBufStr {
        var s = try FixedBufStr.init(a, content.len);
        _ = s.load(content) catch @panic("bug");
        return s;
    }

    pub inline fn capacity(self: FixedBufStr) usize {
        return self.buf.len;
    }

    pub fn deinit(self: *FixedBufStr) void {
        self.a.free(self.buf);
    }

    pub fn load(self: *FixedBufStr, content: []const u8) WriteError!usize {
        if (self.capacity() < content.len) {
            return WriteError.CapacityExceeded;
        }

        @memcpy(self.buf[0..content.len], content);
        self.len = content.len;
        return self.len;
    }

    pub fn loadMany(self: *FixedBufStr, slices: []const []const u8) WriteError!usize {
        if (slices.len == 0) {
            self.len = 0;
            return 0;
        }

        _ = try self.load(slices[0]);
        for (slices[1..slices.len]) |sl| {
            _ = try self.append(sl);
        }
        return self.len;
    }

    pub fn loadStr(self: *FixedBufStr, other: FixedBufStr) WriteError!usize {
        _ = try self.load(other.slice());
        return self.len;
    }

    pub const LoadFileError = (WriteError || std.posix.ReadError || std.io.StreamSource.GetSeekPosError);

    pub fn loadFile(self: *FixedBufStr, file: std.fs.File) LoadFileError!usize {
        const file_size = file.getEndPos() catch |err| switch (err) {
            error.Unseekable => @panic("loadFile file is Unseekable"),
            else => return err,
        };
        if (file_size > self.capacity()) {
            return WriteError.CapacityExceeded;
        }

        const bytes_read = try file.readAll(self.buf);
        std.debug.assert(file_size == bytes_read);
        self.len = file_size;
        return self.len;
    }

    pub fn append(self: *FixedBufStr, content: []const u8) WriteError!usize {
        const newlen = self.len + content.len;
        if (self.capacity() < newlen) {
            return WriteError.CapacityExceeded;
        }

        @memcpy(self.buf[self.len..newlen], content);
        self.len = newlen;
        return content.len;
    }

    pub fn eqlBuf(self: FixedBufStr, content: []const u8) bool {
        if (self.len != content.len) {
            return false;
        }

        return std.mem.eql(u8, self.buf[0..content.len], content);
    }

    pub fn eqlOther(self: FixedBufStr, other: FixedBufStr) bool {
        if (self.len != other.len) {
            return false;
        }

        return std.mem.eql(u8, self.buf[0..other.len], other.buf);
    }

    pub inline fn slice(self: FixedBufStr) []const u8 {
        return self.buf[0..self.len];
    }
};

test "out of memory" {
    const s = FixedBufStr.init(std.testing.failing_allocator, 10);
    try std.testing.expectEqual(FixedBufStr.InitError.OutOfMemory, s);
}

test "eql" {
    var s = try FixedBufStr.initWith(std.testing.allocator, "test");
    defer s.deinit();

    try std.testing.expectEqual(4, s.len);
    try std.testing.expect(s.eqlBuf("test"));

    try std.testing.expect(!s.eqlBuf("tes"));
    try std.testing.expect(!s.eqlBuf("tesa"));
    try std.testing.expect(!s.eqlBuf("test1"));
}

test "too big" {
    var s = try FixedBufStr.init(std.testing.allocator, 5);
    defer s.deinit();

    const err = s.load("abcdef");
    try std.testing.expectEqual(FixedBufStr.WriteError.CapacityExceeded, err);
}

test "smaller than cap" {
    var s = try FixedBufStr.init(std.testing.allocator, 20);
    defer s.deinit();

    _ = try s.load("abcd");

    try std.testing.expectEqual(4, s.len);
    try std.testing.expectEqualSlices(u8, "abcd", s.slice());
}

test "append" {
    var s = try FixedBufStr.init(std.testing.allocator, 4);
    defer s.deinit();

    _ = try s.load("ab");
    _ = try s.append("cd");

    try std.testing.expectEqual(4, s.len);
    try std.testing.expectEqualSlices(u8, "abcd", s.slice());
}

test "append too big" {
    var s = try FixedBufStr.initWith(std.testing.allocator, "ab");
    defer s.deinit();

    const err = s.append("c");
    try std.testing.expectEqual(FixedBufStr.WriteError.CapacityExceeded, err);
}

test "loadMany" {
    var s = try FixedBufStr.init(std.testing.allocator, 20);
    defer s.deinit();

    _ = try s.loadMany(&.{ "a", "bc", "def" });
    try std.testing.expectEqualSlices(u8, "abcdef", s.slice());
}
