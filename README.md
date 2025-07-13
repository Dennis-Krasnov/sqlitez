# sqlitez

- Inspired by https://github.com/karlseguin/zqlite.zig
- Vendors the latest version of sqlite
- Fork if you want different SQLite compilation flags

## Zig Version
sqlitez targets Zig 0.14.

## Installation
1. Add gibe as a dependency in your `build.zig.zon`:
```bash
zig fetch --save git+https://github.com/Dennis-Krasnov/sqlitez#master
```

2. In your `build.zig`, add the `sqlitez` module as a dependency you your program:
```zig
const httpz = b.dependency("sqlitez", .{
    .target = target,
    .optimize = optimize,
});

exe_mod.addImport("sqlitez", gibe.module("sqlitez"));
```

Update by re-running step 1.

## Test
```bash
zig build test --summary all
```

## Examples
```bash
zig build run-single-row
zig build run-many-rows
zig build run-mutation

zig build test-examples --summary all
```
