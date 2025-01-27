const std = @import("std");
const zul = @import("zul");

const DockerCliPluginMeta = struct {
    SchemaVersion: []const u8 = "0.1.0",
    Vendor: []const u8,
    Version: []const u8,
    ShortDescription: []const u8,
};

const Data = struct {
    vendor: []const u8,
    version: []const u8,
    description: []const u8,
};

pub fn run(allocator: std.mem.Allocator, data: Data) !void {
    _ = allocator;

    const meta = DockerCliPluginMeta{
        .Vendor = data.vendor,
        .Version = data.version,
        .ShortDescription = data.description,
    };

    const stdout = std.io.getStdOut();
    try std.json.stringify(meta, .{
        .whitespace = .indent_2,
    }, stdout.writer());
    _ = try stdout.writer().write("\n");
}
