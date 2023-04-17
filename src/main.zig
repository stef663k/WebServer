const std = @import("std");
const net = std.net;
const StreamServer = net.StreamServer;
const Address = net.Address;
pub const io_mode = .evented;

pub fn main() !void {
    const streamServer = StreamServer.init(.{});
    defer streamServer.close();
    const address = try Address.resolveIp("127.0.0.0", 8000);
    streamServer.listen(address);

    while (true) {
        const connection = try streamServer.accept();
        try connection.stream.writer().print("Hello world", .{});
    }
}
