' mpv-open.vbs
' Runs mpv-open.ps1 completely hidden (no PowerShell console flash) and passes
' the incoming "mpv:" URL straight through. This is the target that the
' protocol handler registered by install.ps1 actually invokes.
Option Explicit

Dim fso, shell, scriptDir, ps1, url, cmd
Set fso   = CreateObject("Scripting.FileSystemObject")
Set shell = CreateObject("WScript.Shell")

scriptDir = fso.GetParentFolderName(WScript.ScriptFullName)
ps1       = scriptDir & "\mpv-open.ps1"

If WScript.Arguments.Count > 0 Then
    url = WScript.Arguments(0)
Else
    url = ""
End If

' The URL is percent-encoded by the browser extension, so it contains no
' spaces or quotes and is safe to embed in the command line.
cmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File """ & ps1 & """ """ & url & """"

' 0 = hidden window, False = don't wait for it to finish.
shell.Run cmd, 0, False
