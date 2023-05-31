const std = @import("std");
const net = std.net;
const StreamServer = net.StreamServer;
const Address = net.Address;
const GenerealPurposeAllocator = std.heap.GeneralPurposeAllocator;
const print = std.debug.print;
const http = @import("HttpContext.zig");
const httpContext = http.HttpContext;
const status = http.Status;

pub const io_mode = .evented;

pub fn main() !void {
    // Create a general purpose allocator
    var gpa = GenerealPurposeAllocator(.{}){};
    // Get a reference to the allocator interface
    const allocator = gpa.allocator();
    _ = allocator;
}

// handles the connection asynchrously
pub fn handlerConnection(allocator: std.mem.Allocator, stream: net.Stream) !void {
    // Close the stream
    defer stream.close();
    // Write a simple response to the client
    var http_context = try httpContext.init(allocator, stream);

    // prints httpcontext
    http_context.debugPrint();

    try http_context.respond(status.OK, null, "Hello");
}
