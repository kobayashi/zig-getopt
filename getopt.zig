const std = @import("std");
const ascii = std.ascii;
const mem = std.mem;
const os = std.os;
const expect = std.testing.expect;

pub const Option = struct {
    opt: u8,
    arg: ?[]const u8 = null,
};

pub const Error = error{ InvalidOption, MissingArgument };

pub const OptionsIterator = struct {
    argv: [][*:0]const u8,
    opts: []const u8,

    optind: usize = 1,
    optpos: usize = 1,
    optopt: u8 = undefined,

    pub fn next(self: *OptionsIterator) Error!?Option {
        if (self.optind == self.argv.len)
            return null;

        const arg = self.argv[self.optind];

        if (mem.eql(u8, mem.span(arg), "--")) {
            self.optind += 1;
            return null;
        }

        if (arg[0] != '-' or !ascii.isAlNum(arg[1]))
            return null;

        self.optopt = arg[self.optpos];

        const maybe_i = mem.indexOfScalar(u8, self.opts, self.optopt);
        if (maybe_i) |i| {
            if (i < self.opts.len - 1 and self.opts[i + 1] == ':') {
                if (arg[self.optpos + 1] != 0) {
                    const res = Option{
                        .opt = self.optopt,
                        .arg = mem.sliceTo(arg + self.optpos + 1, 0),
                    };
                    self.optind += 1;
                    self.optpos = 1;
                    return res;
                } else if (self.optind + 1 < self.argv.len) {
                    const res = Option{
                        .opt = self.optopt,
                        .arg = mem.span(self.argv[self.optind + 1]),
                    };
                    self.optind += 2;
                    self.optpos = 1;
                    return res;
                } else return Error.MissingArgument;
            } else {
                self.optpos += 1;
                if (arg[self.optpos] == 0) {
                    self.optind += 1;
                    self.optpos = 1;
                }
                return Option{ .opt = self.optopt };
            }
        } else return Error.InvalidOption;
    }

    pub fn args(self: *OptionsIterator) [][*:0]const u8 {
        return argv[self.optind..];
    }
};

fn getoptArgv(argv: [][*:0]const u8, opts: []const u8) OptionsIterator {
    return OptionsIterator{
        .argv = argv,
        .opts = opts,
    };
}

pub fn getopt(opts: []const u8) OptionsIterator {
    // https://github.com/ziglang/zig/issues/8808
    const argv: [][*:0]const u8 = os.argv;
    return getoptArgv(argv, opts);
}

test "no args separate" {
    var argv = [_][*:0]const u8{
        "getopt",
        "-a",
        "-b",
    };

    const expected = [_]Option{
        .{ .opt = 'a' },
        .{ .opt = 'b' },
    };

    var opts = getoptArgv(&argv, "ab");

    var i: usize = 0;
    while (try opts.next()) |opt| : (i += 1) {
        try expect(opt.opt == expected[i].opt);
        if (opt.arg != null and expected[i].arg != null) {
            try expect(mem.eql(u8, opt.arg.?, expected[i].arg.?));
        } else {
            try expect(opt.arg == null and expected[i].arg == null);
        }
    }
}

test "no args joined" {
    var argv = [_][*:0]const u8{
        "getopt",
        "-abc",
    };

    const expected = [_]Option{
        .{ .opt = 'a' },
        .{ .opt = 'b' },
        .{ .opt = 'c' },
    };

    var opts = getoptArgv(&argv, "abc");

    var i: usize = 0;
    while (try opts.next()) |opt| : (i += 1) {
        try expect(opt.opt == expected[i].opt);
        if (opt.arg != null and expected[i].arg != null) {
            try expect(mem.eql(u8, opt.arg.?, expected[i].arg.?));
        } else {
            try expect(opt.arg == null and expected[i].arg == null);
        }
    }
}

test "with args separate" {
    var argv = [_][*:0]const u8{
        "getopt",
        "-a10",
        "-b",
        "-c",
        "42",
    };

    const expected = [_]Option{
        .{
            .opt = 'a',
            .arg = "10",
        },
        .{ .opt = 'b' },
        .{
            .opt = 'c',
            .arg = "42",
        },
    };

    var opts = getoptArgv(&argv, "a:bc:");

    var i: usize = 0;
    while (try opts.next()) |opt| : (i += 1) {
        try expect(opt.opt == expected[i].opt);
        if (opt.arg != null and expected[i].arg != null) {
            try expect(mem.eql(u8, opt.arg.?, expected[i].arg.?));
        } else {
            try expect(opt.arg == null and expected[i].arg == null);
        }
    }
}

test "with args joined" {
    var argv = [_][*:0]const u8{
        "getopt",
        "-a10",
        "-bc",
        "42",
    };

    const expected = [_]Option{
        .{
            .opt = 'a',
            .arg = "10",
        },
        .{ .opt = 'b' },
        .{
            .opt = 'c',
            .arg = "42",
        },
    };

    var opts = getoptArgv(&argv, "a:bc:");

    var i: usize = 0;
    while (try opts.next()) |opt| : (i += 1) {
        try expect(opt.opt == expected[i].opt);
        if (opt.arg != null and expected[i].arg != null) {
            try expect(mem.eql(u8, opt.arg.?, expected[i].arg.?));
        } else {
            try expect(opt.arg == null and expected[i].arg == null);
        }
    }
}

test "invalid option" {
    var argv = [_][*:0]const u8{
        "getopt",
        "-az",
    };

    var opts = getoptArgv(&argv, "a");

    // -a is ok
    try expect((try opts.next()).?.opt == 'a');

    const maybe_opt = opts.next();
    if (maybe_opt) {
        unreachable;
    } else |err| {
        try expect(err == OptionError.InvalidOption);
        try expect(opts.optopt == 'z');
    }
}

test "missing argument" {
    var argv = [_][*:0]const u8{
        "getopt",
        "-az",
    };

    var opts = getoptArgv(&argv, "az:");

    // -a is ok
    try expect((try opts.next()).?.opt == 'a');

    const maybe_opt = opts.next();
    if (maybe_opt) {
        unreachable;
    } else |err| {
        try expect(err == OptionError.MissingArgument);
        try expect(opts.optopt == 'z');
    }
}