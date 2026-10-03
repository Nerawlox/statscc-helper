Option Explicit
Dim shell, result
Set shell=CreateObject("WScript.Shell")
result=shell.Run("schtasks.exe /Run /TN ""StatsCC Independent Helper""",0,True)
If result<>0 Then MsgBox "Cannot start stats.cc helper. Run Install.cmd first. Error: " & result,vbExclamation,"stats.cc helper"
