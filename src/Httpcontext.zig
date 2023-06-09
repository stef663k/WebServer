const std = @import("std");
const net = std.net;
const StreamServer = net.StreamServer;
const Address = net.Address;
const GenerealPurposeAllocator = std.heap.GeneralPurposeAllocator;
const print = std.debug.print;
const Allocator = std.mem.Allocator;

// Make error enums to use for connection errors
pub const ParsinError = error{
    MethodNotValid,
    VersionNotValid,
};

// Define HTTP call as enums
pub const Method = enum {
    GET,
    POST,
    PUT,
    PATCH,
    OPTION,
    DELETE,

    // Define a function named fromString that takes a slice of bytes and returns a Method or an error
    // This function is used to parse the HTTP method from the stream and convert it to an enum value
    pub fn fromString(s: []const u8) !Method {
        // Compare the slice with each possible value and return the corresponding Method
        if (std.mem.eql(u8, "GET", s)) return .GET;
        if (std.mem.eql(u8, "POST", s)) return .POST;
        if (std.mem.eql(u8, "PUT", s)) return .PUT;
        if (std.mem.eql(u8, "PATCH", s)) return .PATCH;
        if (std.mem.eql(u8, "OPTION", s)) return .OPTION;
        if (std.mem.eql(u8, "DELETE", s)) return .DELETE;
        // If none of the values match, return an error
        return ParsinError.MethodNotValid;
    }
};

// Define HTTP versions as enums
pub const Version = enum {
    @"0.9",
    @"1.1",
    @"2",

    // Define a function named fromString that takes a slice of bytes and returns a Version or an error
    // This function is used to parse the HTTP version from the stream and convert it to an enum value
    pub fn fromString(s: []const u8) !Version {
        // Compare the slice with each possible value and return the corresponding Version
        if (std.mem.eql(u8, "HTTP/0.9", s)) return .@"0.9";
        if (std.mem.eql(u8, "HTTP/1.1", s)) return .@"1.1";
        if (std.mem.eql(u8, "HTTP/2", s)) return .@"2";
        // If none of the values match, return an error
        return ParsinError.VersionNotValid;
    }

    pub fn asString(self: Version) []const u8 {
        if (self == Version.@"0.9") return "HTTP/0.9";
        if (self == Version.@"1.1") return "HTTP/1.1";
        if (self == Version.@"2") return "HTTP/2";
        unreachable;
    }
};

pub const Status = enum {
    OK,

    pub fn asString(self: Status) []const u8 {
        if (self == Status.OK) return "OK";
    }
    pub fn asNumber(self: Status) usize {
        if (self == Status.OK) return 200;
    }
};

// Define a struct named HttpContext that represents the context of an HTTP request
pub const HttpContext = struct {
    // Declare a field named method that holds the HTTP method of the request
    method: Method,
    // Declare a field named uri that holds the URI of the request
    uri: []const u8,
    // Declare a field named version that holds the HTTP version of the request
    version: Version,
    // Declare a field named headers that holds a hash map of the HTTP headers of the request
    headers: std.StringHashMap([]const u8),
    // Declare a field named stream that holds the stream object of the connection
    stream: net.Stream,

    // Define a function named body that takes a pointer to an HttpContext and returns a reader object for the request body
    pub fn bodyReader(self: *HttpContext) !HttpContext {
        return self.stream.reader();
    }

    // Define a function named response that takes an HttpContext and returns a writer object for the response body
    pub fn response(self: HttpContext) net.Stream.Writer {
        return self.stream.writer();
    }

    pub fn respond(self: *HttpContext, status: Status, maybe_headers: ?std.StringHashMap([]const u8), body: []const u8) !void {
        var writer = self.response();
        try writer.print("{s} {} {s}\r\n", .{ self.version.asString(), status.asNumber(), status.asString() });
        if (maybe_headers) |headers| {
            var header_iter = headers.iterator();

            while (header_iter.next()) |entry| {
                try writer.print("{s}: {s}\n", .{ entry.key_ptr.*, entry.value_ptr.* });
            }
        }
        try writer.print("\r\n", .{});
        _ = try writer.write(body);
    }

    // Define a function named debugPrint that takes a pointer to an HttpContext and prints its fields for debugging purposes
    pub fn debugPrint(self: *HttpContext) void {
        print("method: {s}\nuri: {s}\nversion: {s}\n", .{ @tagName(self.method), self.uri, @tagName(self.version) });

        // Iterate over the headers hash map and print each key-value pair
        var headers_iter = self.headers.iterator();
        while (headers_iter.next()) |entry| {
            print("{s}: {s}\n", .{ entry.key_ptr.*, entry.value_ptr.* });
        }
    }

    // Define a function named init that takes an allocator and a stream and returns an HttpContext or an error
    // This function is used to initialize an HttpContext from the stream by parsing the HTTP request
    pub fn init(allocator: std.mem.Allocator, stream: net.Stream) !HttpContext {
        // Read the first line of the request until the newline character and remove the trailing carriage return
        var first_line = try stream.reader().readUntilDelimiterAlloc(allocator, '\n', std.math.maxInt(usize));
        first_line = first_line[0 .. first_line.len - 1];

        // Split the first line by spaces and get the method, uri and version slices
        var first_line_iter = std.mem.split(u8, first_line, " ");

        const method = first_line_iter.next();
        const uri = first_line_iter.next();
        const version = first_line_iter.next();

        // Initialize an empty hash map for the headers
        var headers = std.StringHashMap([]const u8).init(allocator);

        // Loop until an empty line is encountered
        while (true) {
            var line = try stream.reader().readUntilDelimiterAlloc(allocator, '\n', std.math.maxInt(usize));
            line = line[0..line.len];

            if (line.len == 1 and std.mem.eql(u8, line, "\r")) break;
            line = line[0..line.len];
            var line_iter = std.mem.split(u8, line, ";");
            const key = line_iter.next().?;
            var value = line_iter.next().?;
            if (value[0] == ' ') value = value[1..];

            try headers.put(key, value);
        }
        return HttpContext{
            .headers = headers,
            .method = try Method.fromString(method.?),
            .version = try Version.fromString(version.?),
            .uri = uri.?,
            .stream = stream,
        };
    }
};

pub const HttpServer = struct {
    allocator: Allocator,
    config: Config,
    address: net.Address,
    stream_server: net.StreamServer = undefined,
    frames: std.ArrayList(*Connection),

    const Connection = struct {
        frames: @Frame(handlerConnection),
    };

    pub const Config = struct {
        address: []const u8 = "127.0.0.1",
        port: u16 = 8080,
    };

    pub fn deinit(self: *HttpServer) !void {
        self.stream_server.close();
        self.stream_server.deinit();
    }
    // handles the connection asynchrously
    fn handlerConnection(allocator: std.mem.Allocator, stream: net.Stream) !void {
        // Close the stream
        defer stream.close();
        // Write a simple response to the client
        var http_context = try HttpContext.init(allocator, stream);

        // prints httpcontext
        http_context.debugPrint();

        try http_context.respond(Status.OK, null, "Hello");
    }
    pub fn init(allocator: Allocator, config: Config) !HttpServer {
        return HttpServer{
            .allocator = allocator,
            .config = config,
            .address = try Address.resolveIp(config.address, config.port),
            .frames = std.ArrayList(*Connection).init(allocator),
        };
    }
    pub fn listen(self: *HttpServer) !void {
        var streamServer = StreamServer.init(.{});
        // Start listening for incoming connections on the address
        try streamServer.listen(self.address);

        while (true) {
            // Accept a new connection from the stream server
            const connection = try streamServer.accept();
            var conn = try self.allocator.create(Connection);
            conn.* = .{
                .frames = async handlerConnection(self.allocator, connection.stream),
            };
            try self.frames.append(conn);
        }
    }
};
