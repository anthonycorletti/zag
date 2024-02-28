const std = @import("std");
const http = std.http;
const log = std.log.scoped(.server);
const time = std.time;

pub const Config = struct { host: []const u8 = "127.0.0.1", port: u16 = 8080, reuse_address: bool = true, max_request_size: usize = 1024 * 1024 };

pub fn create_http_server(allocator: std.mem.Allocator, config: Config) http.Server {
    var s = http.Server.init(allocator, .{ .reuse_address = config.reuse_address });
    defer s.deinit();
    return s;
}

pub fn run_server(server: *http.Server, allocator: std.mem.Allocator, config: Config) !void {
    outer: while (true) {
        var res = try server.accept(.{
            .allocator = allocator,
        });
        defer res.deinit();

        while (res.reset() != .closing) {
            res.wait() catch |err| switch (err) {
                error.HttpHeadersInvalid => continue :outer,
                error.EndOfStream => continue,
                else => return err,
            };
            if (res.transfer_encoding != .chunked) {
                res.transfer_encoding = .chunked;
            }
            try handle_request(&res, allocator, config);
        }
    }
}

fn handle_request(res: *http.Server.Response, allocator: std.mem.Allocator, config: Config) !void {
    const body = try res.reader().readAllAlloc(allocator, config.max_request_size);
    defer allocator.free(body);

    // Set "connection" header to "keep-alive" if present in request headers.
    if (res.request.headers.contains("connection")) {
        try res.headers.append("connection", "keep-alive");
    }

    // this would probably be something that matches the routes you have registered to routers
    if (std.mem.startsWith(u8, res.request.target, "/echo")) {
        try res.headers.append("content-type", "text/plain; charset=utf-8");
        try res.do();
        if (res.request.method != .HEAD) {
            try res.writeAll("Hey\n");
            try res.writeAll("World\n");
            try res.finish();
        }
    } else {
        res.status = .not_found;
        try res.do();
    }
    log.info("TIME_MS:{d} METHOD:{s} REQUEST_VERSION:{s} TARGET:{s} STATUS_CODE:{d}", .{ time.milliTimestamp(), @tagName(res.request.method), @tagName(res.request.version), res.request.target, res.status });
}
