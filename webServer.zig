const std = @import("std");
const net = std.net;
const StreamServer = net.StreamServer;
const Address = net.Address;
const GenerealPurposeAllocator = std.heap.GeneralPurposeAllocator;
pub const io_mode = .evented;
var gpa = GenerealPurposeAllocator(.{}){};
const allocator = gpa.allocator();

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
    _ = allocator;
    defer stream.close();
    var first_line = stream.reader().readUntilDelimiterAlloc(allocator, '\n', std.math.maxInt(usize));
    first_line = first_line[0..first_line.len];
    var first_line_iter = std.mem.split(u8, first_line, "");

    const method = first_line_iter.next();
    _ = method;
    const uri = first_line_iter.next();
    _ = uri;
    const version = first_line_iter.next();
    _ = version;

    while (true) {
        var line = stream.reader().readUntilDelimiterAlloc(allocator, '\n', std.math.maxInt(usize));
        line = line[0..line.len];

        if (line.len == 2 and std.mem.eql(line, "\r\n")) break;
    }

    try stream.writer().print("Hello world", .{});
}
