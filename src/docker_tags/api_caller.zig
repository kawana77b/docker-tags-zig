const std = @import("std");
const zul = @import("zul");
const pt = @import("prettytable");
const util = @import("../util/util.zig");

pub const schema = @import("./schema.zig");
pub const image_utils = @import("./image_utils.zig");

const model = @import("./image_tag_info.zig");
const exec = @import("./api_request_executor.zig");

pub const ApiCaller = struct {
    arena: std.heap.ArenaAllocator,

    pub const PrintKind = enum {
        table,
        plane,
        plane_with_image,
    };

    pub const PrintOpts = struct {
        kind: PrintKind = .plane,
    };

    const RequestResult = struct {
        owner: *ApiCaller,
        schemas: []model.ImageTagInfo,

        fn init(owner: *ApiCaller, schemas: []model.ImageTagInfo) RequestResult {
            return .{ .owner = owner, .schemas = schemas };
        }

        fn print_table(self: *RequestResult) !void {
            const allocator = self.owner.arena.allocator();

            var table = pt.Table.init(allocator);
            defer table.deinit();

            // set format
            table.setFormat(pt.FORMAT_CLEAN);

            // set title
            const titles = [_][]const u8{
                "image", "tag", "architectures", "full_size", "last_pushed", "image_tag",
            };
            try table.setTitle(&titles);

            // set style
            var r = table.titles.?;
            for (0..titles.len) |i| {
                try r.setCellStyle(i, .{ .bold = true, .fg = .green });
            }

            for (self.schemas) |s| {
                const archs_str = try s.joined_archs(" / ");
                const last_pushed_str = try s.last_pushed_str();
                const full_size_str = try s.full_size_str();
                const image_tag = try s.image_tag();
                try table.addRow(&.{
                    s.image, s.tag, archs_str, full_size_str, last_pushed_str, image_tag,
                });
            }

            try table.print_tty(true);
        }

        fn print_plane(self: *RequestResult, with_image: bool) !void {
            const allocator = self.owner.arena.allocator();
            var values = std.ArrayList([]u8).init(allocator);
            for (self.schemas) |s| {
                if (with_image) {
                    try values.append(try s.image_tag());
                } else {
                    try values.append(s.tag);
                }
            }
            for (values.items) |value| {
                std.debug.print("{s}\n", .{value});
            }
        }

        pub fn print(self: *RequestResult, opts: PrintOpts) !void {
            switch (opts.kind) {
                .table => try self.print_table(),
                .plane => try self.print_plane(false),
                .plane_with_image => try self.print_plane(true),
            }
        }
    };

    pub fn init(allocator: std.mem.Allocator) ApiCaller {
        return .{
            .arena = std.heap.ArenaAllocator.init(allocator),
        };
    }

    pub fn deinit(self: *ApiCaller) void {
        self.arena.deinit();
    }

    const DockerTagApiCallerError = error{
        NoImageName,
    };

    pub fn request(self: *ApiCaller, opts: struct {
        args: [][]const u8,
        limit: u32,
    }) !RequestResult {
        const allocator = self.arena.allocator();

        if (opts.args.len == 0) {
            return DockerTagApiCallerError.NoImageName;
        }

        var req = try exec.ApiRequestExecutor.init(allocator);
        req.image = opts.args[0];
        req.limit = opts.limit;
        req.page_size = 100;
        req.initial_page = 1;
        const schemas = try req.execute();

        //--------------------------------------
        // タグ名順で降順ソートしたリストを再作成する
        //--------------------------------------
        // 辞書でストア
        var tag_maps = std.StringHashMap(model.ImageTagInfo).init(allocator);
        defer tag_maps.deinit();
        for (schemas) |s| {
            try tag_maps.put(s.tag, s);
        }

        // キーでのソートリスト作成
        var tag_sorted = std.ArrayList([]const u8).init(allocator);
        defer tag_sorted.deinit();
        for (schemas) |s| {
            try tag_sorted.append(s.tag);
        }
        zul.sort.strings(tag_sorted.items, .desc);

        // 結果リスト作成
        var results = std.ArrayList(model.ImageTagInfo).init(allocator);
        for (tag_sorted.items) |tag| {
            const s = tag_maps.get(tag).?;
            try results.append(s);
        }
        return RequestResult.init(self, results.items);
    }
};
