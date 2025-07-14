const std = @import("std");
const sqlitez = @import("sqlitez");

pub fn main() !void {
    const connection = try sqlitez.Connection.open(":memory:", sqlitez.OpenFlags.ReadWrite);
    defer connection.close();

    try connection.exec("CREATE TABLE person (id INTEGER PRIMARY KEY, name TEXT NOT NULL) STRICT;");

    const statement = try connection.prepare("INSERT INTO person(name) VALUES (?1)");
    defer statement.finalize();

    for ([_][]const u8{ "Alice", "Bob", "Charlie" }) |name| {
        defer statement.reset() catch {};
        try statement.bindText(1, name);
        std.debug.assert(try statement.step() == null);
    }

    try printAllPersons(connection);
}

fn printAllPersons(db: sqlitez.Connection) !void {
    const statement = try db.prepare("SELECT id, name FROM person");
    defer statement.finalize();

    defer statement.reset() catch {};
    while (try statement.step()) |row| {
        std.log.info("person: {d} {s}", .{ row.int(0), row.text(1) });
    }
}

test "smoke" {}
