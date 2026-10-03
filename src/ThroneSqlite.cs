using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;

// Windows' SQLite library; the database is always opened read-only.
public static class ThroneSqlite {
    [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)]
    private static extern IntPtr LoadLibraryEx(string name, IntPtr file, uint flags);
    [DllImport("winsqlite3.dll", CallingConvention=CallingConvention.Cdecl)]
    private static extern int sqlite3_open_v2(byte[] path, out IntPtr db, int flags, IntPtr vfs);
    [DllImport("winsqlite3.dll", CallingConvention=CallingConvention.Cdecl)]
    private static extern int sqlite3_close(IntPtr db);
    [DllImport("winsqlite3.dll", CallingConvention=CallingConvention.Cdecl)]
    private static extern int sqlite3_busy_timeout(IntPtr db, int ms);
    [DllImport("winsqlite3.dll", CallingConvention=CallingConvention.Cdecl)]
    private static extern int sqlite3_prepare_v2(IntPtr db, byte[] sql, int length, out IntPtr stmt, IntPtr tail);
    [DllImport("winsqlite3.dll", CallingConvention=CallingConvention.Cdecl)]
    private static extern int sqlite3_step(IntPtr stmt);
    [DllImport("winsqlite3.dll", CallingConvention=CallingConvention.Cdecl)]
    private static extern int sqlite3_finalize(IntPtr stmt);
    [DllImport("winsqlite3.dll", CallingConvention=CallingConvention.Cdecl)]
    private static extern int sqlite3_column_count(IntPtr stmt);
    [DllImport("winsqlite3.dll", CallingConvention=CallingConvention.Cdecl)]
    private static extern IntPtr sqlite3_column_text(IntPtr stmt, int column);
    [DllImport("winsqlite3.dll", CallingConvention=CallingConvention.Cdecl)]
    private static extern int sqlite3_column_bytes(IntPtr stmt, int column);

    static ThroneSqlite() {
        if (LoadLibraryEx("winsqlite3.dll", IntPtr.Zero, 0x800) == IntPtr.Zero)
            throw new InvalidOperationException("WindowsSQLiteUnavailable");
    }
    public static string[][] Query(string path, string sql) {
        IntPtr db = IntPtr.Zero, stmt = IntPtr.Zero;
        var rows = new List<string[]>();
        try {
            if (sqlite3_open_v2(Encoding.UTF8.GetBytes(path+"\0"), out db, 1, IntPtr.Zero) != 0)
                throw new InvalidOperationException("ThroneDatabaseUnreadable");
            sqlite3_busy_timeout(db, 3000);
            byte[] query = Encoding.UTF8.GetBytes(sql+"\0");
            if (sqlite3_prepare_v2(db, query, query.Length, out stmt, IntPtr.Zero) != 0)
                throw new InvalidOperationException("ThroneSchemaUnsupported");
            int code;
            while ((code = sqlite3_step(stmt)) == 100) {
                var row = new string[sqlite3_column_count(stmt)];
                for (int i=0; i<row.Length; i++) {
                    IntPtr p = sqlite3_column_text(stmt, i);
                    int length = sqlite3_column_bytes(stmt, i);
                    if (length > 4*1024*1024) throw new InvalidOperationException("ThroneValueTooLarge");
                    byte[] value = new byte[length];
                    if (length > 0) Marshal.Copy(p,value,0,length);
                    row[i] = Encoding.UTF8.GetString(value);
                }
                rows.Add(row);
            }
            if (code != 101) throw new InvalidOperationException("ThroneDatabaseReadFailed");
            return rows.ToArray();
        } finally {
            if (stmt != IntPtr.Zero) sqlite3_finalize(stmt);
            if (db != IntPtr.Zero) sqlite3_close(db);
        }
    }
}
