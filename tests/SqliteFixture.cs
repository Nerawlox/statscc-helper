using System;
using System.Runtime.InteropServices;
using System.Text;
public static class SqliteFixture {
    [DllImport("winsqlite3.dll", CallingConvention=CallingConvention.Cdecl)]
    private static extern int sqlite3_open_v2(byte[] path,out IntPtr db,int flags,IntPtr vfs);
    [DllImport("winsqlite3.dll", CallingConvention=CallingConvention.Cdecl)]
    private static extern int sqlite3_exec(IntPtr db,byte[] sql,IntPtr callback,IntPtr arg,IntPtr error);
    [DllImport("winsqlite3.dll", CallingConvention=CallingConvention.Cdecl)]
    private static extern int sqlite3_close(IntPtr db);
    public static void Create(string path,string outbound) {
        IntPtr db=IntPtr.Zero;
        try {
            if (sqlite3_open_v2(Encoding.UTF8.GetBytes(path+"\0"),out db,6,IntPtr.Zero)!=0) throw new Exception("FixtureOpenFailed");
            string sql="CREATE TABLE profiles(id INTEGER,name TEXT,type TEXT,gid INTEGER,outbound_json TEXT);"+
                "CREATE TABLE groups(id INTEGER,front_proxy_id INTEGER,landing_proxy_id INTEGER);"+
                "INSERT INTO groups VALUES(1,-1,-1);"+
                "INSERT INTO profiles VALUES(7,'Synthetic profile','xrayvless',1,'"+outbound.Replace("'","''")+"');";
            if(sqlite3_exec(db,Encoding.UTF8.GetBytes(sql+"\0"),IntPtr.Zero,IntPtr.Zero,IntPtr.Zero)!=0) throw new Exception("FixtureWriteFailed");
        } finally { if(db!=IntPtr.Zero) sqlite3_close(db); }
    }
}
