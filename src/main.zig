const std = @import("std");
const build_options = @import("build_options");
const clap = @import("clap");

const util = @import("./util/util.zig");
const cmd = @import("./cmd/cmd.zig");

const APP_VERSION = build_options.version;
const APP_NAME = build_options.app_name;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer {
        const deinit_status = gpa.deinit();
        if (deinit_status == .leak) {
            util.console.errln("Error: Memory leak detected") catch unreachable;
        }
    }

    const params = comptime clap.parseParamsComptime(
        \\-h, --help             Display this help and exit.
        \\-v, --version          Output version information and exit.
        \\-i, --with-image       Connect and display image names and tags.
        \\-b, --browse           Open the URL in the browser.
        \\-l, --limit <count>    Limit the number of tags to display. (default: 30)
        \\-d, --detail           Displays detailed information in table.
        \\<IMAGE>...
        \\
    );

    const parsers = comptime .{
        .count = clap.parsers.int(u32, 0),
        .IMAGE = clap.parsers.string,
    };

    var diag = clap.Diagnostic{};
    var res = clap.parse(clap.Help, &params, parsers, .{
        .diagnostic = &diag,
        .allocator = allocator,
    }) catch |err| {
        diag.report(std.io.getStdErr().writer(), err) catch {};
        return err;
    };
    defer res.deinit();

    // --help
    if (res.args.help != 0) {
        const description =
            \\ Usage: {s} [options] <IMAGE>...
            \\
            \\ Description: Search for image tags from DockerHub
            \\
        ;
        std.debug.print(description ++ "\n", .{APP_NAME});
        return clap.help(std.io.getStdErr().writer(), clap.Help, &params, .{});
    }
    // --version
    if (res.args.version != 0) {
        std.debug.print("{s} {s}\n", .{ APP_NAME, APP_VERSION });
        return;
    }

    // set options
    return cmd.root.run(allocator, res);
}
