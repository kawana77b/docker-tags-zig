const std = @import("std");
const zul = @import("zul");
const util = @import("../util/util.zig");

pub const ImageTagInfo = struct {
    arena: *std.heap.ArenaAllocator,

    image: []u8 = "",
    tag: []u8 = "",
    archs: std.ArrayList([]u8) = undefined,
    last_pushed: ?zul.DateTime = null,
    full_size: ?u32 = null,

    pub fn init(allocator: std.mem.Allocator) !ImageTagInfo {
        const arena = try allocator.create(std.heap.ArenaAllocator);
        errdefer allocator.destroy(arena);
        arena.* = std.heap.ArenaAllocator.init(allocator);
        return .{
            .arena = arena,
            .tag = "",
            .archs = std.ArrayList([]u8).init(arena.allocator()),
        };
    }

    pub fn deinit(self: *ImageTagInfo) void {
        self.arena.deinit();
    }

    pub fn image_tag(self: ImageTagInfo) ![]u8 {
        const allocator = self.arena.allocator();
        return try std.fmt.allocPrint(allocator, "{s}:{s}", .{ self.image, self.tag });
    }

    pub fn joined_archs(self: ImageTagInfo, sep: []const u8) ![]u8 {
        const allocator = self.arena.allocator();
        return try std.mem.join(allocator, sep, self.archs.items);
    }

    pub fn last_pushed_str(self: ImageTagInfo) ![]u8 {
        const allocator = self.arena.allocator();
        if (self.last_pushed) |d| {
            const date = d.date();
            const time = d.time();
            return try std.fmt.allocPrint(
                allocator,
                "{d}-{d:0>2}-{d:0>2} {d:0>2}:{d:0>2}:{d:0>2}",
                .{ date.year, date.month, date.day, time.hour, time.min, time.sec },
            );
        }
        return @constCast("N/A");
    }

    pub fn full_size_str(self: ImageTagInfo) ![]u8 {
        const allocator = self.arena.allocator();
        if (self.full_size) |size| {
            return try util.get_readable_size(allocator, size);
        }
        return @constCast("0.00 B");
    }
};
