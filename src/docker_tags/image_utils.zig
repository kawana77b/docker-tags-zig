const std = @import("std");

/// Check if the image name is an official image.
pub fn is_official(image: []u8) bool {
    return std.mem.indexOf(u8, image, "/") == null;
}

/// Get the URL to browse the Docker image
pub fn get_browse_url(allocator: std.mem.Allocator, image: []u8) ![]u8 {
    if (is_official(image)) {
        return std.fmt.allocPrint(allocator, "https://hub.docker.com/_/{s}", .{image});
    }
    return std.fmt.allocPrint(allocator, "https://hub.docker.com/r/{s}", .{image});
}
