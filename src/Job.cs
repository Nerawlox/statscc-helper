using System;
using System.ComponentModel;
using System.Diagnostics;
using System.Runtime.InteropServices;
public sealed class StatsHelperJob : IDisposable {
    [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)]
    private static extern IntPtr CreateJobObject(IntPtr attributes, string name);
    [DllImport("kernel32.dll", SetLastError=true)]
    private static extern bool SetInformationJobObject(IntPtr job, int infoClass, IntPtr info, uint length);
    [DllImport("kernel32.dll", SetLastError=true)]
    private static extern bool AssignProcessToJobObject(IntPtr job, IntPtr process);
    [DllImport("kernel32.dll")]
    private static extern bool CloseHandle(IntPtr handle);
    private IntPtr handle;
    public StatsHelperJob() {
        handle = CreateJobObject(IntPtr.Zero, null);
        if (handle == IntPtr.Zero) throw new Win32Exception();
        // JOBOBJECT_EXTENDED_LIMIT_INFORMATION: LimitFlags at offset 16.
        // Kill only the two helper children when their controller disappears.
        int size = IntPtr.Size == 8 ? 144 : 112;
        IntPtr data = Marshal.AllocHGlobal(size);
        try {
            for (int i=0; i<size; i++) Marshal.WriteByte(data, i, 0);
            Marshal.WriteInt32(data, 16, 0x2000);
            if (!SetInformationJobObject(handle, 9, data, (uint)size)) throw new Win32Exception();
        } catch { CloseHandle(handle); handle=IntPtr.Zero; throw; }
        finally { Marshal.FreeHGlobal(data); }
    }
    public void Add(Process process) {
        if (!AssignProcessToJobObject(handle, process.Handle)) throw new Win32Exception();
    }
    public void Dispose() {
        if (handle != IntPtr.Zero) { CloseHandle(handle); handle = IntPtr.Zero; }
    }
}
