const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const test_filters = b.option([]const []const u8, "test-filter", "Skip tests that don't match the filter") orelse &.{};

    const sqlite_source = std.Build.Module.CSourceFile{
        .file = b.path("lib/sqlite3.c"),
        .flags = &[_][]const u8{
            // disable useless features
            "-DSQLITE_DQS=0", // double quoted string literals
            "-DSQLITE_DEFAULT_MEMSTATUS=0", // tracking memory usage
            "-DSQLITE_MAX_EXPR_DEPTH=0", // checking expression parse-tree depth
            "-DSQLITE_OMIT_DECLTYPE", // declared type of columns
            "-DSQLITE_OMIT_DEPRECATED",
            "-DSQLITE_OMIT_PROGRESS_CALLBACK", // conditional from bytecode engine
            "-DSQLITE_OMIT_SHARED_CACHE", // many conditionals, signifant performance improvement

            // optimizations
            "-DSQLITE_THREADSAFE=2", // multiple threads don't use a connection at the same time
            "-DSQLITE_TEMP_STORE=3", // use in-memory transient indices and temporary tables
            "-DSQLITE_LIKE_DOESNT_MATCH_BLOBS", // speeds up queries that use LIKE optimization
            "-DSQLITE_USE_ALLOCA", // allocates stack space using alloca instead of the heap

            // extra features
            "-DSQLITE_STRICT_SUBTYPE=1", // ensures function is registered with result subtype property
            "-DSQLITE_DEFAULT_FOREIGN_KEYS=1", // off by default
            "-DSQLITE_ENABLE_API_ARMOR", // detects api misuse
        },
    };

    const sqlitez_module = b.addModule("sqlitez", .{
        .root_source_file = b.path("src/sqlitez.zig"),
        .target = target,
        .optimize = optimize,
    });
    sqlitez_module.addCSourceFile(sqlite_source);
    sqlitez_module.link_libc = true;

    // test
    const unit_test = b.addTest(.{ .root_module = sqlitez_module, .filters = test_filters });
    const run_unit_test = b.addRunArtifact(unit_test);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_test.step);

    buildExamples(b, sqlitez_module, target, optimize, test_filters);
}

const examples = [_][]const u8{
    "single_row",
    "many_rows",
    "mutation",
    "disk",
};

pub fn buildExamples(b: *std.Build, sqlitez_module: *std.Build.Module, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode, test_filters: []const []const u8) void {
    const test_step = b.step("test-examples", "Run unit tests in examples");

    inline for (examples) |example| {
        // build
        const exe_mod = b.createModule(.{
            .root_source_file = b.path("examples/" ++ example ++ ".zig"),
            .target = target,
            .optimize = optimize,
        });
        exe_mod.addImport("sqlitez", sqlitez_module);

        const exe = b.addExecutable(.{ .name = example, .root_module = exe_mod });

        b.installArtifact(exe);

        // run
        const run_exe = b.addRunArtifact(exe);

        const run_step = b.step("run-" ++ comptime camelToKebabCase(example), "Run examples/" ++ example ++ ".zig");
        run_step.dependOn(&run_exe.step);

        // test
        const unit_test_mod = b.createModule(.{
            .root_source_file = b.path("examples/" ++ example ++ ".zig"),
            .target = target,
            .optimize = optimize,
        });
        unit_test_mod.addImport("sqlitez", sqlitez_module);

        const unit_test = b.addTest(.{ .root_module = unit_test_mod, .filters = test_filters });
        const run_unit_test = b.addRunArtifact(unit_test);

        test_step.dependOn(&run_unit_test.step);
    }
}

fn camelToKebabCase(comptime string: []const u8) []const u8 {
    comptime var result: [string.len]u8 = undefined;

    for (string, 0..) |c, i| {
        result[i] = if (c == '_') '-' else c;
    }

    return &result;
}
