const std = @import("std");
const debug = std.debug;
const getopt = @import("getopt.zig");

pub fn main() void {
    var arg: []const u8 = undefined;
    var verbose: bool = false;

    var opts = getopt.getopt("a:vh");

    while (opts.next()) |maybe_opt| {
        if (maybe_opt) |opt| {
            switch (opt.opt) {
                'a' => {
                    arg = opt.arg.?;
                    debug.print("arg = {s}\n", .{arg});
                },
                'v' => {
                    verbose = true;
                    debug.print("verbose = {}\n", .{verbose});
                },
                'h' => debug.print(
                    \\usage: example [-a arg] [-hv]
                    \\
                , .{}),
                else => unreachable,
            }
        } else break;
    } else |err| {
        switch (err) {
            getopt.Error.InvalidOption => debug.print("invalid option: {c}\n", .{opts.optopt}),
            getopt.Error.MissingArgument => debug.print("option requires an argument: {c}\n", .{opts.optopt}),
        }
    }
}
