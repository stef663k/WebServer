const std = @import("std");
const net = std.net;
const StreamServer = net.StreamServer;
const Address = net.Address;
const GenerealPurposeAllocator = std.heap.GeneralPurposeAllocator;
const print = std.debug.print;
const http = @import("HttpContext.zig");
const httpContext = http.HttpContext;
const status = http.Status;
const HTTPServer = http.HttpServer;

pub const io_mode = .evented;

pub fn main() !void {
    // Create a general purpose allocator
    var gpa = GenerealPurposeAllocator(.{}){};
    // Get a reference to the allocator interface
    const allocator = gpa.allocator();

    var server = try HTTPServer.init(allocator, .{});
    try server.listen();
}
