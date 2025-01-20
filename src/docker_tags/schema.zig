const std = @import("std");

pub const DockerTagsApiResponse = struct {
    const Result = struct {
        const Image = struct {
            architecture: ?[]u8 = null,
            features: ?[]u8 = null,
            variant: ?[]u8 = null,
            digest: ?[]u8 = null,
            os: ?[]u8 = null,
            os_features: ?[]u8 = null,
            os_version: ?[]u8 = null,
            size: ?u32 = null,
            status: ?[]u8 = null,
            last_pulled: ?[]u8 = null,
            last_pushed: ?[]u8 = null,
        };
        creator: ?u32 = null,
        id: u32,
        images: []Image,
        last_updated: ?[]u8 = null,
        last_updater: ?u32 = null,
        last_updater_username: ?[]u8 = null,
        name: []u8,
        repository: ?u32 = null,
        full_size: ?u32 = null,
        v2: bool,
        tag_status: ?[]u8 = null,
        tag_last_pulled: ?[]u8 = null,
        tag_last_pushed: ?[]u8 = null,
        media_type: ?[]u8 = null,
        content_type: ?[]u8 = null,
        digest: ?[]u8 = null,
    };
    count: u32,
    next: ?[]u8 = null,
    previous: ?[]u8 = null,
    results: []Result,
};
