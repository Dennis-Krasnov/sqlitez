const std = @import("std");

pub const c = @cImport(@cInclude("sqlite3.h"));

pub const OpenFlags = struct {
    pub const Create = c.SQLITE_OPEN_CREATE;
    pub const ReadOnly = c.SQLITE_OPEN_READONLY;
    pub const ReadWrite = c.SQLITE_OPEN_READWRITE;
    pub const DeleteOnClose = c.SQLITE_OPEN_DELETEONCLOSE;
    pub const Exclusive = c.SQLITE_OPEN_EXCLUSIVE;
    pub const AutoProxy = c.SQLITE_OPEN_AUTOPROXY;
    pub const Uri = c.SQLITE_OPEN_URI;
    pub const Memory = c.SQLITE_OPEN_MEMORY;
    pub const MainDB = c.SQLITE_OPEN_MAIN_DB;
    pub const TempDB = c.SQLITE_OPEN_TEMP_DB;
    pub const TransientDB = c.SQLITE_OPEN_TRANSIENT_DB;
    pub const MainJournal = c.SQLITE_OPEN_MAIN_JOURNAL;
    pub const TempJournal = c.SQLITE_OPEN_TEMP_JOURNAL;
    pub const SubJournal = c.SQLITE_OPEN_SUBJOURNAL;
    pub const SuperJournal = c.SQLITE_OPEN_SUPER_JOURNAL;
    pub const NoMutex = c.SQLITE_OPEN_NOMUTEX;
    pub const FullMutex = c.SQLITE_OPEN_FULLMUTEX;
    pub const SharedCache = c.SQLITE_OPEN_SHAREDCACHE;
    pub const PrivateCache = c.SQLITE_OPEN_PRIVATECACHE;
    pub const OpenWAL = c.SQLITE_OPEN_WAL;
    pub const NoFollow = c.SQLITE_OPEN_NOFOLLOW;
    pub const EXResCode = c.SQLITE_OPEN_EXRESCODE;
};

pub const Connection = struct {
    _inner: *c.sqlite3,

    /// Must later call close.
    pub fn open(path: [*:0]const u8, flags: c_int) !Connection {
        var connection: ?*c.sqlite3 = null;
        const rc = c.sqlite3_open_v2(path, &connection, flags | c.SQLITE_OPEN_EXRESCODE, null);
        if (rc != c.SQLITE_OK) {
            return errorFromCode(rc);
        }

        return Connection{ ._inner = connection.? };
    }

    /// Consumes self.
    pub fn close(self: Connection) void {
        _ = c.sqlite3_close_v2(self._inner);
    }

    /// Must later call finalize.
    pub fn prepare(self: Connection, sql: []const u8) !Statement {
        var statement: ?*c.sqlite3_stmt = null;
        const rc = c.sqlite3_prepare_v2(self._inner, sql.ptr, @intCast(sql.len), &statement, null);
        if (rc != c.SQLITE_OK) {
            return errorFromCode(rc);
        }
        return Statement{ ._inner = statement.? };
    }

    /// ...
    pub fn exec(self: Connection, sql: [*:0]const u8) !void {
        const rc = c.sqlite3_exec(self._inner, sql, null, null, null);
        if (rc != c.SQLITE_OK) {
            return errorFromCode(rc);
        }
    }

    /// ...
    pub fn get_user_version(self: Connection) !i32 {
        const statement = try self.prepare("PRAGMA user_version");
        const row = (try statement.step()).?;
        return @intCast(row.int(0));
    }

    pub fn set_user_version(self: Connection, user_version: i32) !void {
        var buffer: [64]u8 = undefined;
        var fba = std.heap.FixedBufferAllocator.init(&buffer);

        const sql = try std.fmt.allocPrintZ(fba.allocator(), "PRAGMA user_version = {d}", .{user_version});
        defer fba.allocator().free(sql);

        try self.exec(sql);
    }
};

pub const Statement = struct {
    _inner: *c.sqlite3_stmt,

    /// Consumes self.
    pub fn finalize(self: Statement) void {
        _ = c.sqlite3_finalize(self._inner);
    }

    /// ...
    pub fn bindNull(self: Statement, comptime index: usize) !void {
        if (index == 0) {
            @compileError("SQLite bind parameters are 1-indexed");
        }

        const rc = c.sqlite3_bind_null(self._inner, @intCast(index));
        if (rc != c.SQLITE_OK) {
            return errorFromCode(rc);
        }
    }

    /// ...
    pub fn bindInt(self: Statement, comptime index: usize, value: i64) !void {
        if (index == 0) {
            @compileError("SQLite bind parameters are 1-indexed");
        }

        const rc = c.sqlite3_bind_int64(self._inner, @intCast(index), @intCast(value));
        if (rc != c.SQLITE_OK) {
            return errorFromCode(rc);
        }
    }

    /// ...
    pub fn bindFloat(self: Statement, comptime index: usize, value: f64) !void {
        if (index == 0) {
            @compileError("SQLite bind parameters are 1-indexed");
        }

        const rc = c.sqlite3_bind_double(self._inner, @intCast(index), @floatCast(value));
        if (rc != c.SQLITE_OK) {
            return errorFromCode(rc);
        }
    }

    /// ...
    pub fn bindText(self: Statement, comptime index: usize, value: []const u8) !void {
        if (index == 0) {
            @compileError("SQLite bind parameters are 1-indexed");
        }

        const rc = c.sqlite3_bind_text(self._inner, @intCast(index), value.ptr, @intCast(value.len), c.SQLITE_STATIC);
        if (rc != c.SQLITE_OK) {
            return errorFromCode(rc);
        }
    }

    /// ...
    pub fn bindBlob(self: Statement, comptime index: usize, value: []const u8) !void {
        if (index == 0) {
            @compileError("SQLite bind parameters are 1-indexed");
        }

        const rc = c.sqlite3_bind_blob(self._inner, @intCast(index), value.ptr, @intCast(value.len), c.SQLITE_STATIC);
        if (rc != c.SQLITE_OK) {
            return errorFromCode(rc);
        }
    }

    /// ...
    pub fn step(self: Statement) !?Row {
        const rc = c.sqlite3_step(self._inner);
        if (rc == c.SQLITE_DONE) {
            return null;
        }
        if (rc != c.SQLITE_ROW) {
            return errorFromCode(rc);
        }
        return Row{ ._inner = self._inner };
    }

    /// Returns the same error as the previous call to step.
    pub fn reset(self: Statement) !void {
        switch (c.sqlite3_reset(self._inner)) {
            c.SQLITE_OK => return,
            else => |rc| return errorFromCode(rc),
        }
    }

    pub fn clearBindings(self: Statement) !void {
        switch (c.sqlite3_clear_bindings(self._inner)) {
            c.SQLITE_OK => return,
            else => |rc| return errorFromCode(rc),
        }
    }
};

pub const Row = struct {
    _inner: *c.sqlite3_stmt,

    pub fn int(self: Row, index: usize) i64 {
        return @intCast(c.sqlite3_column_int64(self._inner, @intCast(index)));
    }

    pub fn nullableInt(self: Row, index: usize) ?i64 {
        if (self.isNull(index)) return null;
        return self.int(index);
    }

    pub fn float(self: Row, index: usize) f64 {
        return @floatCast(c.sqlite3_column_double(self._inner, @intCast(index)));
    }

    pub fn nullableFloat(self: Row, index: usize) ?f64 {
        if (self.isNull(index)) return null;
        return self.float(index);
    }

    pub fn text(self: Row, index: usize) []const u8 {
        const pointer = c.sqlite3_column_text(self._inner, @intCast(index));
        const len = c.sqlite3_column_bytes(self._inner, @intCast(index));
        return @as([*c]const u8, @ptrCast(pointer))[0..@intCast(len)];
    }

    pub fn nullableText(self: Row, index: usize) ?[]const u8 {
        if (self.isNull(index)) return null;
        return self.text(index);
    }

    pub fn blob(self: Row, index: usize) []const u8 {
        const pointer = c.sqlite3_column_blob(self._inner, @intCast(index));
        const len = c.sqlite3_column_bytes(self._inner, @intCast(index));
        return @as([*c]const u8, @ptrCast(pointer))[0..@intCast(len)];
    }

    pub fn nullableBlob(self: Row, index: usize) ?[]const u8 {
        if (self.isNull(index)) return null;
        return self.blob(index);
    }

    fn isNull(self: Row, index: usize) bool {
        return c.sqlite3_column_type(self._inner, @intCast(index)) == c.SQLITE_NULL;
    }
};

fn errorFromCode(result: c_int) Error {
    return switch (result) {
        c.SQLITE_ABORT => Error.Abort,
        c.SQLITE_AUTH => Error.Auth,
        c.SQLITE_BUSY => Error.Busy,
        c.SQLITE_CANTOPEN => Error.CantOpen,
        c.SQLITE_CONSTRAINT => Error.Constraint,
        c.SQLITE_CORRUPT => Error.Corrupt,
        c.SQLITE_EMPTY => Error.Empty,
        c.SQLITE_ERROR => Error.Error,
        c.SQLITE_FORMAT => Error.Format,
        c.SQLITE_FULL => Error.Full,
        c.SQLITE_INTERNAL => Error.Internal,
        c.SQLITE_INTERRUPT => Error.Interrupt,
        c.SQLITE_IOERR => Error.IoErr,
        c.SQLITE_LOCKED => Error.Locked,
        c.SQLITE_MISMATCH => Error.Mismatch,
        c.SQLITE_MISUSE => Error.Misuse,
        c.SQLITE_NOLFS => Error.NoLFS,
        c.SQLITE_NOMEM => Error.NoMem,
        c.SQLITE_NOTADB => Error.NotADB,
        c.SQLITE_NOTFOUND => Error.Notfound,
        c.SQLITE_NOTICE => Error.Notice,
        c.SQLITE_PERM => Error.Perm,
        c.SQLITE_PROTOCOL => Error.Protocol,
        c.SQLITE_RANGE => Error.Range,
        c.SQLITE_READONLY => Error.ReadOnly,
        c.SQLITE_SCHEMA => Error.Schema,
        c.SQLITE_TOOBIG => Error.TooBig,
        c.SQLITE_WARNING => Error.Warning,

        // extended codes
        c.SQLITE_ERROR_MISSING_COLLSEQ => Error.ErrorMissingCollseq,
        c.SQLITE_ERROR_RETRY => Error.ErrorRetry,
        c.SQLITE_ERROR_SNAPSHOT => Error.ErrorSnapshot,
        c.SQLITE_IOERR_READ => Error.IoerrRead,
        c.SQLITE_IOERR_SHORT_READ => Error.IoerrShortRead,
        c.SQLITE_IOERR_WRITE => Error.IoerrWrite,
        c.SQLITE_IOERR_FSYNC => Error.IoerrFsync,
        c.SQLITE_IOERR_DIR_FSYNC => Error.IoerrDir_fsync,
        c.SQLITE_IOERR_TRUNCATE => Error.IoerrTruncate,
        c.SQLITE_IOERR_FSTAT => Error.IoerrFstat,
        c.SQLITE_IOERR_UNLOCK => Error.IoerrUnlock,
        c.SQLITE_IOERR_RDLOCK => Error.IoerrRdlock,
        c.SQLITE_IOERR_DELETE => Error.IoerrDelete,
        c.SQLITE_IOERR_BLOCKED => Error.IoerrBlocked,
        c.SQLITE_IOERR_NOMEM => Error.IoerrNomem,
        c.SQLITE_IOERR_ACCESS => Error.IoerrAccess,
        c.SQLITE_IOERR_CHECKRESERVEDLOCK => Error.IoerrCheckreservedlock,
        c.SQLITE_IOERR_LOCK => Error.IoerrLock,
        c.SQLITE_IOERR_CLOSE => Error.IoerrClose,
        c.SQLITE_IOERR_DIR_CLOSE => Error.IoerrDirClose,
        c.SQLITE_IOERR_SHMOPEN => Error.IoerrShmopen,
        c.SQLITE_IOERR_SHMSIZE => Error.IoerrShmsize,
        c.SQLITE_IOERR_SHMLOCK => Error.IoerrShmlock,
        c.SQLITE_IOERR_SHMMAP => Error.Ioerrshmmap,
        c.SQLITE_IOERR_SEEK => Error.IoerrSeek,
        c.SQLITE_IOERR_DELETE_NOENT => Error.IoerrDeleteNoent,
        c.SQLITE_IOERR_MMAP => Error.IoerrMmap,
        c.SQLITE_IOERR_GETTEMPPATH => Error.IoerrGetTempPath,
        c.SQLITE_IOERR_CONVPATH => Error.IoerrConvPath,
        c.SQLITE_IOERR_VNODE => Error.IoerrVnode,
        c.SQLITE_IOERR_AUTH => Error.IoerrAuth,
        c.SQLITE_IOERR_BEGIN_ATOMIC => Error.IoerrBeginAtomic,
        c.SQLITE_IOERR_COMMIT_ATOMIC => Error.IoerrCommitAtomic,
        c.SQLITE_IOERR_ROLLBACK_ATOMIC => Error.IoerrRollbackAtomic,
        c.SQLITE_IOERR_DATA => Error.IoerrData,
        c.SQLITE_IOERR_CORRUPTFS => Error.IoerrCorruptFS,
        c.SQLITE_LOCKED_SHAREDCACHE => Error.LockedSharedCache,
        c.SQLITE_LOCKED_VTAB => Error.LockedVTab,
        c.SQLITE_BUSY_RECOVERY => Error.BusyRecovery,
        c.SQLITE_BUSY_SNAPSHOT => Error.BusySnapshot,
        c.SQLITE_BUSY_TIMEOUT => Error.BusyTimeout,
        c.SQLITE_CANTOPEN_NOTEMPDIR => Error.CantOpenNoTempDir,
        c.SQLITE_CANTOPEN_ISDIR => Error.CantOpenIsDir,
        c.SQLITE_CANTOPEN_FULLPATH => Error.CantOpenFullPath,
        c.SQLITE_CANTOPEN_CONVPATH => Error.CantOpenConvPath,
        c.SQLITE_CANTOPEN_DIRTYWAL => Error.CantOpenDirtyWal,
        c.SQLITE_CANTOPEN_SYMLINK => Error.CantOpenSymlink,
        c.SQLITE_CORRUPT_VTAB => Error.CorruptVTab,
        c.SQLITE_CORRUPT_SEQUENCE => Error.CorruptSequence,
        c.SQLITE_CORRUPT_INDEX => Error.CorruptIndex,
        c.SQLITE_READONLY_RECOVERY => Error.ReadonlyRecovery,
        c.SQLITE_READONLY_CANTLOCK => Error.ReadonlyCantlock,
        c.SQLITE_READONLY_ROLLBACK => Error.ReadonlyRollback,
        c.SQLITE_READONLY_DBMOVED => Error.ReadonlyDbMoved,
        c.SQLITE_READONLY_CANTINIT => Error.ReadonlyCantInit,
        c.SQLITE_READONLY_DIRECTORY => Error.ReadonlyDirectory,
        c.SQLITE_ABORT_ROLLBACK => Error.AbortRollback,
        c.SQLITE_CONSTRAINT_CHECK => Error.ConstraintCheck,
        c.SQLITE_CONSTRAINT_COMMITHOOK => Error.ConstraintCommithook,
        c.SQLITE_CONSTRAINT_FOREIGNKEY => Error.ConstraintForeignKey,
        c.SQLITE_CONSTRAINT_FUNCTION => Error.ConstraintFunction,
        c.SQLITE_CONSTRAINT_NOTNULL => Error.ConstraintNotNull,
        c.SQLITE_CONSTRAINT_PRIMARYKEY => Error.ConstraintPrimaryKey,
        c.SQLITE_CONSTRAINT_TRIGGER => Error.ConstraintTrigger,
        c.SQLITE_CONSTRAINT_UNIQUE => Error.ConstraintUnique,
        c.SQLITE_CONSTRAINT_VTAB => Error.ConstraintVTab,
        c.SQLITE_CONSTRAINT_ROWID => Error.ConstraintRowId,
        c.SQLITE_CONSTRAINT_PINNED => Error.ConstraintPinned,
        c.SQLITE_CONSTRAINT_DATATYPE => Error.ConstraintDatatype,
        c.SQLITE_NOTICE_RECOVER_WAL => Error.NoticeRecoverWal,
        c.SQLITE_NOTICE_RECOVER_ROLLBACK => Error.NoticeRecoverRollback,
        c.SQLITE_WARNING_AUTOINDEX => Error.WarningAutoIndex,
        c.SQLITE_AUTH_USER => Error.AuthUser,
        c.SQLITE_OK_LOAD_PERMANENTLY => Error.OkLoadPermanently,

        else => std.debug.panic("{s} {d}", .{ c.sqlite3_errstr(result), result }),
    };
}

pub const Error = error{
    Abort,
    Auth,
    Busy,
    CantOpen,
    Constraint,
    Corrupt,
    Empty,
    Error,
    Format,
    Full,
    Internal,
    Interrupt,
    IoErr,
    Locked,
    Mismatch,
    Misuse,
    NoLFS,
    NoMem,
    NotADB,
    Notfound,
    Notice,
    Perm,
    Protocol,
    Range,
    ReadOnly,
    Schema,
    TooBig,
    Warning,
    ErrorMissingCollseq,
    ErrorRetry,
    ErrorSnapshot,
    IoerrRead,
    IoerrShortRead,
    IoerrWrite,
    IoerrFsync,
    IoerrDir_fsync,
    IoerrTruncate,
    IoerrFstat,
    IoerrUnlock,
    IoerrRdlock,
    IoerrDelete,
    IoerrBlocked,
    IoerrNomem,
    IoerrAccess,
    IoerrCheckreservedlock,
    IoerrLock,
    IoerrClose,
    IoerrDirClose,
    IoerrShmopen,
    IoerrShmsize,
    IoerrShmlock,
    Ioerrshmmap,
    IoerrSeek,
    IoerrDeleteNoent,
    IoerrMmap,
    IoerrGetTempPath,
    IoerrConvPath,
    IoerrVnode,
    IoerrAuth,
    IoerrBeginAtomic,
    IoerrCommitAtomic,
    IoerrRollbackAtomic,
    IoerrData,
    IoerrCorruptFS,
    LockedSharedCache,
    LockedVTab,
    BusyRecovery,
    BusySnapshot,
    BusyTimeout,
    CantOpenNoTempDir,
    CantOpenIsDir,
    CantOpenFullPath,
    CantOpenConvPath,
    CantOpenDirtyWal,
    CantOpenSymlink,
    CorruptVTab,
    CorruptSequence,
    CorruptIndex,
    ReadonlyRecovery,
    ReadonlyCantlock,
    ReadonlyRollback,
    ReadonlyDbMoved,
    ReadonlyCantInit,
    ReadonlyDirectory,
    AbortRollback,
    ConstraintCheck,
    ConstraintCommithook,
    ConstraintForeignKey,
    ConstraintFunction,
    ConstraintNotNull,
    ConstraintPrimaryKey,
    ConstraintTrigger,
    ConstraintUnique,
    ConstraintVTab,
    ConstraintRowId,
    ConstraintPinned,
    ConstraintDatatype,
    NoticeRecoverWal,
    NoticeRecoverRollback,
    WarningAutoIndex,
    AuthUser,
    OkLoadPermanently,
};

test "select null" {
    const connection = try Connection.open(":memory:", OpenFlags.ReadWrite);
    const statement = try connection.prepare("SELECT NULL");
    const row = (try statement.step()).?;

    try std.testing.expectEqual(row.nullableInt(0), null);
    try std.testing.expectEqual(row.nullableFloat(0), null);
    try std.testing.expectEqual(row.nullableText(0), null);
    try std.testing.expectEqual(row.nullableBlob(0), null);
}

test "select integer" {
    const connection = try Connection.open(":memory:", OpenFlags.ReadWrite);
    const statement = try connection.prepare("SELECT 123");
    const row = (try statement.step()).?;

    try std.testing.expectEqual(row.int(0), 123);
    try std.testing.expectEqual(row.nullableInt(0), 123);
}

test "select real" {
    const connection = try Connection.open(":memory:", OpenFlags.ReadWrite);
    const statement = try connection.prepare("SELECT 1.5");
    const row = (try statement.step()).?;

    try std.testing.expectEqual(row.float(0), 1.5);
    try std.testing.expectEqual(row.nullableFloat(0), 1.5);
}

test "select text" {
    const connection = try Connection.open(":memory:", OpenFlags.ReadWrite);
    const statement = try connection.prepare("SELECT 'hello'");
    const row = (try statement.step()).?;

    try std.testing.expectEqualStrings(row.text(0), "hello");
    try std.testing.expectEqualStrings(row.nullableText(0).?, "hello");
}

test "select blob" {
    const connection = try Connection.open(":memory:", OpenFlags.ReadWrite);
    const statement = try connection.prepare("SELECT CAST('hello' AS BLOB)");
    const row = (try statement.step()).?;

    try std.testing.expectEqualStrings(row.blob(0), "hello");
    try std.testing.expectEqualStrings(row.nullableBlob(0).?, "hello");
}

test "bind null" {
    const connection = try Connection.open(":memory:", OpenFlags.ReadWrite);
    const statement = try connection.prepare("SELECT ?1");
    try statement.bindNull(1);
    const row = (try statement.step()).?;

    try std.testing.expectEqual(row.nullableInt(0), null);
}

test "bind integer" {
    const connection = try Connection.open(":memory:", OpenFlags.ReadWrite);
    const statement = try connection.prepare("SELECT ?1");
    try statement.bindInt(1, 123);
    const row = (try statement.step()).?;

    try std.testing.expectEqual(row.int(0), 123);
}

test "bind real" {
    const connection = try Connection.open(":memory:", OpenFlags.ReadWrite);
    const statement = try connection.prepare("SELECT ?1");
    try statement.bindFloat(1, 1.5);
    const row = (try statement.step()).?;

    try std.testing.expectEqual(row.float(0), 1.5);
}

test "bind text" {
    const connection = try Connection.open(":memory:", OpenFlags.ReadWrite);
    const statement = try connection.prepare("SELECT ?1");
    try statement.bindText(1, "hello");
    const row = (try statement.step()).?;

    try std.testing.expectEqualStrings(row.text(0), "hello");
}

test "bind blob" {
    const connection = try Connection.open(":memory:", OpenFlags.ReadWrite);
    const statement = try connection.prepare("SELECT ?1");
    try statement.bindBlob(1, "hello");
    const row = (try statement.step()).?;

    try std.testing.expectEqualStrings(row.blob(0), "hello");
}

test "execute statements several times" {
    const connection = try Connection.open(":memory:", OpenFlags.ReadWrite);
    const statement = try connection.prepare("SELECT 123");

    for (0..5) |_| {
        defer statement.reset() catch {};
        const row = (try statement.step()).?;

        try std.testing.expectEqual(row.int(0), 123);
    }
}

test "user version" {
    const connection = try Connection.open(":memory:", OpenFlags.ReadWrite);

    try std.testing.expectEqual(try connection.get_user_version(), 0);

    try connection.set_user_version(123);
    try std.testing.expectEqual(try connection.get_user_version(), 123);
}
