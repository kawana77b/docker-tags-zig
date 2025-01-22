const std = @import("std");
const zul = @import("zul");
const model = @import("./image_tag_info.zig");
const schema = @import("./schema.zig");
const image_utils = @import("./image_utils.zig");

const ApiRequestError = error{
    ConnectionFailed,
    NotSuccessfulStatusCode,
};

pub const ApiRequestExecutor = struct {
    pub const DEFAULT_PAGE_SIZE = 100;
    pub const DEFAULT_INITIAL_PAGE = 1;

    arena: *std.heap.ArenaAllocator,

    image: []const u8 = "",
    limit: u32 = 30,

    page_size: u32 = DEFAULT_PAGE_SIZE,
    initial_page: u32 = DEFAULT_INITIAL_PAGE,

    pub fn init(allocator: std.mem.Allocator) !ApiRequestExecutor {
        const arena = try allocator.create(std.heap.ArenaAllocator);
        errdefer allocator.destroy(arena);
        arena.* = std.heap.ArenaAllocator.init(allocator);
        return .{
            .arena = arena,
        };
    }

    pub fn deinit(self: *ApiRequestExecutor) void {
        self.arena.deinit();
    }

    fn create_init_url(self: *ApiRequestExecutor) ![]u8 {
        const allocator = self.arena.allocator();
        const fmt = comptime "https://hub.docker.com/v2/repositories/{s}/tags?page={d}&page_size={d}";

        var image_url_parts = zul.StringBuilder.init(allocator);
        if (image_utils.is_official(@constCast(self.image))) {
            try image_url_parts.write("library/");
        }
        try image_url_parts.write(self.image);

        return try std.fmt.allocPrint(allocator, fmt, .{ image_url_parts.string(), self.initial_page, self.page_size });
    }

    pub fn execute(self: *ApiRequestExecutor) ![]model.ImageTagInfo {
        const allocator = self.arena.allocator();

        var results = std.ArrayList(model.ImageTagInfo).init(allocator);

        var client = zul.http.Client.init(allocator);
        defer client.deinit();

        var access_url: []u8 = try self.create_init_url();
        outer: while (true) {
            var req = client.request(access_url) catch {
                return ApiRequestError.ConnectionFailed;
            };
            defer req.deinit();

            var res = try req.getResponse(.{});
            if (res.status >= 300) {
                return ApiRequestError.NotSuccessfulStatusCode;
            }

            const parsed = try res.json(schema.DockerTagsApiResponse, allocator, .{});

            // スキーマ情報をセット
            const v = parsed.value;
            for (v.results) |s| {
                var item = try model.ImageTagInfo.init(allocator);
                item.image = @constCast(self.image);
                item.tag = s.name;
                item.full_size = s.full_size;
                for (s.images) |image| {
                    if (image.architecture) |arch| {
                        // archにunknownが含まれるため、それ以外を追加
                        if (!std.mem.eql(u8, arch, "unknown")) {
                            try item.archs.append(arch);
                        }
                    }
                    if (image.last_pushed) |last_pushed| {
                        item.last_pushed = zul.DateTime.parse(last_pushed, .rfc3339) catch null;
                    }
                }
                // アーキテクチャは順序が不定なのでソートする
                zul.sort.strings(item.archs.items, .asc);
                try results.append(item);

                if (results.items.len >= self.limit) break :outer;
            }

            if (v.next == null) break;

            access_url = v.next.?;
        }
        return results.items;
    }
};
