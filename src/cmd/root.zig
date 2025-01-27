const std = @import("std");
const clap = @import("clap");
const util = @import("../util//util.zig");
const docker_tags = @import("../docker_tags/docker_tags.zig");
const build_options = @import("build_options");

pub const RootOptions = struct {
    const DEFULAT_LIMIT = 30;

    with_image: bool,
    browse: bool,
    detail: bool,
    limit: u32,
    args: std.ArrayList([]const u8),

    fn init(allocator: std.mem.Allocator) RootOptions {
        return .{
            .with_image = false,
            .detail = false,
            .browse = false,
            .limit = RootOptions.DEFULAT_LIMIT,
            .args = std.ArrayList([]const u8).init(allocator),
        };
    }

    fn deinit(self: *RootOptions) void {
        self.args.deinit();
    }

    fn print_kind(self: RootOptions) docker_tags.ApiCaller.PrintKind {
        if (self.detail) {
            return .table;
        }
        if (self.with_image) {
            return .plane_with_image;
        }
        return .plane;
    }
};

const ARG_PARSE_ERROR = error{
    DOCKER_SUBCOMMAND_NOT_FOUND,
};

// Get subcommand from app_name
fn subcommand() ARG_PARSE_ERROR![]const u8 {
    var iter = std.mem.split(u8, build_options.app_name, "-");
    _ = iter.next();
    return iter.next() orelse error.DOCKER_SUBCOMMAND_NOT_FOUND;
}

fn parse_opts(comptime T: type, allocator: std.mem.Allocator, clap_result: T) !RootOptions {
    var root_opts = RootOptions.init(allocator);
    const res = clap_result;

    root_opts.limit = res.args.limit orelse RootOptions.DEFULAT_LIMIT;
    root_opts.with_image = res.args.@"with-image" != 0;
    root_opts.browse = res.args.browse != 0;
    root_opts.detail = res.args.detail != 0;
    for (res.positionals) |pos| {
        // When used from Docker, it skips the arguments of the subcommand.
        if (std.mem.eql(u8, pos, try subcommand())) continue;
        try root_opts.args.append(pos);
    }

    return root_opts;
}

pub fn run(allocator: std.mem.Allocator, clap_result: anytype) !void {
    var opts = try parse_opts(@TypeOf(clap_result), allocator, clap_result);
    defer opts.deinit();

    if (opts.args.items.len == 0) {
        try util.console.errln("Error: No image name provided");
        return;
    }

    // open browser if browse flag is set
    if (opts.browse) {
        const image = @constCast(opts.args.items[0]);
        const browser_url = try docker_tags.image_utils.get_browse_url(allocator, image);
        defer allocator.free(browser_url);

        // open browser, and go to docker hub page
        util.open_browser(browser_url) catch |err| {
            try util.console.fmt_errln(allocator, "Error: {}", .{err});
        };
        return;
    }

    // request docker tags
    var api = docker_tags.ApiCaller.init(allocator);
    defer api.deinit();
    var api_result = api.request(.{
        .args = opts.args.items,
        .limit = opts.limit,
    }) catch |err| {
        try util.console.fmt_errln(allocator, "Error: {}", .{err});
        return;
    };

    // print result
    try api_result.print(.{
        .kind = opts.print_kind(),
    });
}
