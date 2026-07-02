#Requires -Version 5.1
<#
.SYNOPSIS
    Sends a YouTube (or any yt-dlp supported) URL to mpv.

.DESCRIPTION
    If an mpv instance started by this tool is already running, the URL is
    appended to its playlist over mpv's JSON IPC pipe ("add to my instance").
    Otherwise a brand-new mpv instance is launched to play it.

    mpv streams the video with yt-dlp via its built-in ytdl_hook. yt-dlp is
    expected to live next to mpv.exe (or on PATH); the path can also be pinned
    in config.ps1.

    This script is normally invoked by the "mpv:" URL protocol handler that
    install.ps1 registers, but it also works standalone:

        .\mpv-open.ps1 "https://youtu.be/dQw4w9WgXcQ"

.NOTES
    Configuration lives in config.ps1 (created by install.ps1). See
    config.example.ps1 for the available settings.
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Url
)

$ErrorActionPreference = 'Stop'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# --- Load configuration (optional) -----------------------------------------
$configPath = Join-Path $scriptDir 'config.ps1'
if (Test-Path $configPath) {
    . $configPath
}

# Fall back to sensible defaults for anything config.ps1 didn't set.
if (-not $PipeName)     { $PipeName = 'mpv-autoopen' }
if (-not $MpvExtraArgs) { $MpvExtraArgs = @() }

# --- Logging (handy when launched invisibly via the protocol) --------------
$logPath = Join-Path $scriptDir 'mpv-autoopen.log'
function Write-Log([string]$msg) {
    try {
        $line = '{0}  {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $msg
        Add-Content -LiteralPath $logPath -Value $line -Encoding UTF8
    } catch { }
}

# --- Locate mpv.exe ---------------------------------------------------------
function Resolve-Mpv {
    if ($MpvPath -and (Test-Path $MpvPath)) {
        return (Resolve-Path $MpvPath).Path
    }
    $cmd = Get-Command 'mpv.exe' -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }

    # String interpolation (not Join-Path) so a missing env var just yields a
    # path that fails Test-Path instead of throwing.
    $candidates = @(
        "$env:ProgramFiles\mpv\mpv.exe",
        "${env:ProgramFiles(x86)}\mpv\mpv.exe",
        "$env:LOCALAPPDATA\Programs\mpv\mpv.exe",
        "$env:USERPROFILE\scoop\apps\mpv\current\mpv.exe",
        "$env:ProgramData\chocolatey\bin\mpv.exe"
    )
    foreach ($c in $candidates) {
        if ($c -and (Test-Path $c)) { return (Resolve-Path $c).Path }
    }
    return $null
}

# --- Turn the raw protocol argument into a clean URL -----------------------
function Get-CleanUrl([string]$raw) {
    if (-not $raw) { return $null }
    $u = $raw.Trim().Trim('"')
    # Strip the custom scheme: "mpv:", "mpv://" (case-insensitive).
    $u = $u -replace '(?i)^\s*mpv:(//)?', ''
    # The browser side percent-encodes the real URL, so decode it once.
    try { $u = [System.Uri]::UnescapeDataString($u) } catch { }
    return $u.Trim()
}

# --- Append to a running mpv over its JSON IPC pipe ------------------------
function Send-ToRunningMpv([string]$targetUrl) {
    $pipe = New-Object System.IO.Pipes.NamedPipeClientStream(
        '.', $PipeName, [System.IO.Pipes.PipeDirection]::InOut)
    try {
        $pipe.Connect(400)   # ms; throws if no server (i.e. mpv not running)
    } catch {
        return $false
    }
    try {
        $writer = New-Object System.IO.StreamWriter($pipe)
        $writer.AutoFlush = $true
        $writer.NewLine = "`n"   # mpv IPC wants plain \n terminated lines
        # append-play => append to the playlist, and start playing if idle.
        $load = @{ command = @('loadfile', $targetUrl, 'append-play') } | ConvertTo-Json -Compress
        $writer.WriteLine($load)
        # If the instance was paused/idle, make sure it resumes.
        $play = @{ command = @('set_property', 'pause', $false) } | ConvertTo-Json -Compress
        $writer.WriteLine($play)
        $writer.Flush()
        Start-Sleep -Milliseconds 60
        return $true
    } finally {
        $pipe.Dispose()
    }
}

# --- Launch a fresh mpv instance -------------------------------------------
# Double-quote any token containing whitespace. We build ONE argument string
# (not an array) so Start-Process passes our quoting through verbatim -- an
# array would drop the quotes and split paths like "C:\Program Files\...".
function Quote-Arg([string]$a) {
    if ($a -match '\s') { return '"' + $a + '"' } else { return $a }
}

function Start-NewMpv([string]$mpv, [string]$targetUrl) {
    $tokens = @("--input-ipc-server=\\.\pipe\$PipeName")
    if ($YtdlpPath -and (Test-Path $YtdlpPath)) {
        $tokens += "--script-opts=ytdl_hook-ytdl_path=$YtdlpPath"
    }
    $tokens += $MpvExtraArgs
    $tokens += '--'          # nothing after this is treated as an option
    $tokens += ($targetUrl -replace '"', '')   # URLs never legitimately contain quotes

    $argLine = ($tokens | ForEach-Object { Quote-Arg $_ }) -join ' '
    Start-Process -FilePath $mpv -ArgumentList $argLine | Out-Null
}

function Show-Error([string]$text) {
    try {
        Add-Type -AssemblyName System.Windows.Forms
        [System.Windows.Forms.MessageBox]::Show($text, 'mpv-autoopen',
            'OK', 'Error') | Out-Null
    } catch { }
}

# --- Main -------------------------------------------------------------------
try {
    $target = Get-CleanUrl $Url
    if (-not $target -or $target -notmatch '(?i)^https?://') {
        Write-Log "Ignored invalid input: '$Url'"
        exit 1
    }
    Write-Log "Request: $target"

    if (Send-ToRunningMpv $target) {
        Write-Log "Appended to running mpv (pipe: $PipeName)."
        exit 0
    }

    $mpv = Resolve-Mpv
    if (-not $mpv) {
        Write-Log 'ERROR: mpv.exe not found.'
        Show-Error "Could not find mpv.exe.`r`nEdit config.ps1 and set `$MpvPath, then try again."
        exit 2
    }

    Write-Log "Starting new mpv: $mpv"
    Start-NewMpv $mpv $target
    exit 0
}
catch {
    Write-Log "EXCEPTION: $($_.Exception.Message)"
    Show-Error "mpv-autoopen failed:`r`n$($_.Exception.Message)"
    exit 3
}
