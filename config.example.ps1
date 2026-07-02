# config.example.ps1
#
# Copy this file to config.ps1 (or just run install.ps1, which generates one
# for you) and edit the values below. mpv-open.ps1 loads config.ps1 if present;
# if it is missing, the script falls back to auto-detecting mpv.exe.

# Full path to your mpv.exe.
$MpvPath = 'C:\Program Files\mpv\mpv.exe'

# Full path to yt-dlp.exe.
# Leave as $null to let mpv find it automatically (mpv looks next to mpv.exe
# and on PATH). Since you dropped yt-dlp.exe into your mpv folder, $null works;
# pinning the path just makes it explicit.
$YtdlpPath = $null

# Named pipe used to reach an already-running mpv instance. Only mpv instances
# started by this tool (with --input-ipc-server on this pipe) can be reached,
# so don't change it unless you have a reason to.
$PipeName = 'mpv-autoopen'

# Extra arguments applied ONLY when a brand-new mpv instance is started
# (not when appending to an existing one).
#
# Tip: to keep a single mpv window alive and just pile videos into it, use:
#   $MpvExtraArgs = @('--idle=yes', '--keep-open=yes', '--force-window=immediate')
$MpvExtraArgs = @()
