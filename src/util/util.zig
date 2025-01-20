const std = @import("std");
const builtin = @import("builtin");
const chroma = @import("chroma");

/// Look for a command in the PATH environment variable.
/// If a non-null string is returned, its memory must be freed by the allocator.
pub fn look_path(allocator: std.mem.Allocator, cmd: []const u8) ?[]const u8 {
    const path_env = std.posix.getenv("PATH") orelse "";
    if (path_env.len == 0) return null;

    const delimiter = if (builtin.os.tag == .windows) ";" else ":";
    var paths = std.mem.split(u8, path_env, delimiter);
    return while (paths.next()) |path| {
        const joins = [2][]const u8{ path, cmd };
        const cmd_abs = std.fs.path.join(allocator, &joins) catch break null;
        // In case of error, return null to terminate, freeing memory in the join path
        errdefer allocator.free(cmd_abs);

        const stat: ?std.fs.File.Stat = std.fs.cwd().statFile(cmd_abs) catch null;
        if (stat) |_| {
            break cmd_abs;
        }
        // Free memory in the join path if the loop is to continue
        allocator.free(cmd_abs);
    } else null;
}

/// Check if a file exists.
fn file_exists(path: []const u8) bool {
    std.fs.cwd().access(path, .{}) catch {
        return false;
    };
    return true;
}

pub const OpenBrowserError = error{
    NotSupportedOS,
    Xdg_OpenNotFound,
    BadUrl,
};

/// Open a URL in the default browser.
pub fn open_browser(url: []const u8) !void {
    const uri = std.Uri.parse(url) catch |err| {
        return err;
    };
    if (!std.mem.startsWith(u8, uri.scheme, "http")) {
        return OpenBrowserError.BadUrl;
    }

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer {
        const deinit_status = gpa.deinit();
        if (deinit_status == .leak) {
            std.debug.print("Memory leak detected in function open_browser.\n", .{});
        }
    }

    var args = std.ArrayList([]const u8).init(allocator);
    defer args.deinit();

    switch (builtin.os.tag) {
        .windows => {
            try args.append("cmd");
            try args.append("/c");
            try args.append("start");
        },
        .linux => {
            const xdg_open = look_path(allocator, "xdg-open") orelse return OpenBrowserError.Xdg_OpenNotFound;
            defer allocator.free(xdg_open);
            if (xdg_open.len > 0) {
                try args.append("xdg-open");
            }
        },
        .macos => {
            try args.append("open");
        },
        else => return OpenBrowserError.NotSupportedOS,
    }
    try args.append(url);

    var cp = std.process.Child.init(args.items, allocator);
    _ = try cp.spawnAndWait();
}

pub const console = struct {
    pub fn errln(comptime msg: []const u8) !void {
        var w = std.io.getStdErr().writer();
        const decorated_mg = comptime "{red}" ++ msg ++ "{reset}";
        const fmt = comptime chroma.format(decorated_mg ++ "\n");
        try w.writeAll(fmt);
    }

    pub fn fmt_errln(allocator: std.mem.Allocator, comptime msg: []const u8, args: anytype) !void {
        var w = std.io.getStdErr().writer();
        const decorated_mg = comptime "{red}" ++ msg ++ "{reset}";
        const fmt = comptime chroma.format(decorated_mg ++ "\n");

        const printed = try std.fmt.allocPrintZ(allocator, fmt, args);
        defer allocator.free(printed);
        try w.writeAll(printed);
    }
};

/// Get a human-readable file length. cf, 3.28 GB
pub fn get_readable_size(allocator: std.mem.Allocator, bytes: u32) ![]u8 {
    const units = comptime [_][]const u8{ "B", "KB", "MB", "GB", "TB" };
    var i: usize = 0;
    var s: f32 = @floatFromInt(bytes);
    while (s >= 1024) : (i += 1) {
        s /= 1024;
        if (i == units.len - 1) break;
    }
    return std.fmt.allocPrint(allocator, "{d:.2} {s}", .{ s, units[i] });
}
