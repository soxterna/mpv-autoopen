#Requires -Version 5.1
<#
.SYNOPSIS
    Removes the "mpv:" URL protocol registration created by install.ps1.
    Leaves config.ps1 and the log file in place (delete the folder to remove
    those too).
#>
[CmdletBinding()]
param()

$base = 'HKCU:\Software\Classes\mpv'
if (Test-Path $base) {
    Remove-Item -Path $base -Recurse -Force
    Write-Host 'Removed the mpv: protocol registration (HKCU).' -ForegroundColor Green
} else {
    Write-Host 'No mpv: protocol registration found - nothing to do.' -ForegroundColor Yellow
}

Write-Host ''
Write-Host 'Also remove the browser extension from chrome://extensions if you loaded it.'
Write-Host 'config.ps1 and mpv-autoopen.log were left untouched.'
