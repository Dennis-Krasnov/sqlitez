const std = @import("std");
const sqlitez = @import("sqlitez");

pub fn main() !void {
    const connection = try sqlitez.Connection.open("/tmp/db.sqlite", sqlitez.OpenFlags.Create | sqlitez.OpenFlags.ReadWrite);
    defer connection.close();

    const statement = try connection.prepare("SELECT 123");
    defer statement.finalize();

    defer statement.reset() catch {};
    const row = (try statement.step()).?;
    defer std.debug.assert(statement.step() catch null == null);

    std.log.info("number: {d}", .{row.int(0)});
}

test "smoke" {}
