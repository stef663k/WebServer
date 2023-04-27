const std = @import("std");
const net = std.net;
const StreamServer = net.StreamServer;
const Address = net.Address;
pub const io_mode = .evented;

pub fn main() !void {
    var streamServer = StreamServer.init(.{});
    defer streamServer.close();
    const address = try Address.resolveIp("127.0.0.1", 8080);
    try streamServer.listen(address);

    while (true) {
        const connection = try streamServer.accept();
        try handlerConnection(connection.stream);
    }
}

fn handlerConnection(stream: net.Stream) !void {
    defer stream.close();
    try stream.writer().print("Hello world", .{});
}
