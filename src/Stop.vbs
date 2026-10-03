Option Explicit
Dim shell,fso,path,request
Set shell=CreateObject("WScript.Shell")
Set fso=CreateObject("Scripting.FileSystemObject")
path=shell.ExpandEnvironmentStrings("%ProgramData%") & "\StatsCC Helper\stop.request"
If fso.FileExists(path) Then
  Set request=fso.OpenTextFile(path,2,False)
  request.WriteLine "stop"
  request.Close
End If
