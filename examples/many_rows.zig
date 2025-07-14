const std = @import("std");
const sqlitez = @import("sqlitez");

pub fn main() !void {
    const connection = try sqlitez.Connection.open(":memory:", sqlitez.OpenFlags.ReadWrite);
    defer connection.close();

    const statement = try connection.prepare("SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3");
    defer statement.finalize();

    defer statement.reset() catch {};
    while (try statement.step()) |row| {
        std.log.info("number: {d}", .{row.int(0)});
    }
}

test "smoke" {}
