const std = @import("std");
const server = @import("server.zig");
const log = std.log;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    var config = server.Config{
        .port = 8080,
    };
    var s = server.create_http_server(allocator, config);
    log.info("Server running at http://{s}:{d}", .{ config.host, config.port });
    const addr = std.net.Address.parseIp(config.host, config.port) catch unreachable;
    try s.listen(addr);

    server.run_server(&s, allocator, config) catch |err| {
        log.err("Server Error: {}\n", .{err});
        if (@errorReturnTrace()) |trace| {
            std.debug.dumpStackTrace(trace.*);
        }
        std.os.exit(1);
    };
}
