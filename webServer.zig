const std = @import("std");
const net = std.net;
const StreamServer = net.StreamServer;
const Address = net.Address;
const GenerealPurposeAllocator = std.heap.GeneralPurposeAllocator;
pub const io_mode = .evented;

pub fn main() !void {
    var gpa = GenerealPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    _ = allocator;
    var streamServer = StreamServer.init(.{});
    defer streamServer.close();
    const address = try Address.resolveIp("127.0.0.1", 8080);
    try streamServer.listen(address);

    while (true) {
        const connection = try streamServer.accept();
        try handlerConnection(connection.stream);
    }
}

fn handlerConnection(allocator: std.mem.Allocator, stream: net.Stream) !void {
    defer stream.close();
    var first_line = stream.reader().readUntilDelimiterArrayList(allocator, '\n', std.math.maxInt(usize));
    _ = first_line;
    try stream.writer().print("Hello world", .{});
}
