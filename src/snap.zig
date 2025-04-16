const std = @import("std");
const Allocator = std.mem.Allocator;

const FixedBufStr = @import("fixed_buf_str.zig").FixedBufStr;

/// A snapshot testing session.
///
/// Contains utilities for iterating over all possible snapshots and writing
/// results to the output.
pub const SnapshotTestSession = struct {
    pub const SNAP_PATH = "snap";
    pub const OUT_PATH = "test-out";

    /// String max lengths
    pub const NAME_CAP = 256;
    pub const INPUT_CAP = 1 << 16;
    pub const EXPECT_CAP = 1 << 16;
    pub const _TMP_STR_CAP = 1024;

    name: FixedBufStr,
    input: FixedBufStr,
    expect: FixedBufStr,

    _tmp_str: FixedBufStr,
    dir_walker: std.fs.Dir.Walker,
    ext: []const u8,

    pub fn init(a: Allocator, ext: []const u8) Allocator.Error!SnapshotTestSession {
        const snap_dir = std.fs.cwd().openDir(SNAP_PATH, .{ .iterate = true }) catch |err| @panic(@errorName(err));

        var tmp_str = try FixedBufStr.init(a, _TMP_STR_CAP);
        errdefer tmp_str.deinit();

        var name = try FixedBufStr.init(a, NAME_CAP);
        errdefer name.deinit();

        var input = try FixedBufStr.init(a, INPUT_CAP);
        errdefer input.deinit();

        var expect = try FixedBufStr.init(a, EXPECT_CAP);
        errdefer expect.deinit();

        var walker = try snap_dir.walk(a);
        errdefer walker.deinit();

        return SnapshotTestSession{
            ._tmp_str = tmp_str,
            .name = name,
            .input = input,
            .expect = expect,
            .dir_walker = walker,
            .ext = ext,
        };
    }

    pub fn deinit(self: *SnapshotTestSession) void {
        self.name.deinit();
        self.input.deinit();
        self.expect.deinit();
        self.dir_walker.deinit();
        self._tmp_str.deinit();
    }

    pub const IterError = FixedBufStr.WriteError || FixedBufStr.LoadFileError || std.fs.File.OpenError;

    pub fn next(self: *SnapshotTestSession) IterError!?[]const u8 {
        const cwd = std.fs.cwd();
        while (self.dir_walker.next() catch |err| @panic(@errorName(err))) |entry| {
            if (entry.kind != std.fs.Dir.Entry.Kind.file) {
                continue;
            }

            const py_path = entry.path;

            if (!std.mem.eql(u8, py_path[py_path.len - 3 .. py_path.len], ".py")) {
                continue;
            }

            const name = py_path[0 .. py_path.len - 3];
            _ = try self.name.load(name);

            _ = try self._tmp_str.loadMany(&.{ SNAP_PATH, "/", py_path });
            const py_file = try cwd.openFile(self._tmp_str.slice(), .{});
            defer py_file.close();
            _ = try self.input.loadFile(py_file);

            _ = try self._tmp_str.loadMany(&.{ SNAP_PATH, "/", name, ".", self.ext });
            const snap_file = try cwd.createFile(self._tmp_str.slice(), .{ .read = true, .truncate = false });
            defer snap_file.close();
            _ = try self.expect.loadFile(snap_file);

            return self.input.slice();
        }

        return null;
    }

    /// Write the result of the latest run for a snapshot to the corresponding out file then assert
    /// it is what we expect from the pristine snapshot file.
    pub fn submitResult(self: *SnapshotTestSession, result: []const u8) !void {
        const cwd = std.fs.cwd();

        _ = try self._tmp_str.loadMany(&.{ OUT_PATH, "/", self.name.slice(), ".", self.ext });
        const f = try cwd.createFile(self._tmp_str.slice(), .{ .truncate = true });
        defer f.close();

        _ = try f.writer().writeAll(result);

        try std.testing.expectEqualSlices(u8, self.expect.slice(), result);
    }
};
