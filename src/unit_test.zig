//! Entrypoint for unit tests

comptime {
    _ = @import("fixed_buf_str.zig");
    _ = @import("main.zig");
    _ = @import("token.zig");
}
