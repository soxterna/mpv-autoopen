# mpv-autoopen

Right-click a YouTube video in your browser and send it straight to **mpv**,
streamed through **yt-dlp**. If an mpv window is already open, the video is
**added to its playlist**; otherwise a new mpv window starts playing it.

Windows only. You point it at your `mpv.exe`, and it uses the `yt-dlp.exe` you
already dropped into your mpv folder.

```
Browser (right-click "Add to mpv")
        │
        ▼
  mpv: URL protocol   ──►  mpv-open.vbs  ──►  mpv-open.ps1
                                                  │
                          ┌───────────────────────┴───────────────────────┐
                          │ mpv already running?                           │
                          │   yes → append to its playlist over IPC pipe   │
                          │   no  → launch a new mpv window (uses yt-dlp)   │
                          └────────────────────────────────────────────────┘
```

## What's in here

| File | Purpose |
|------|---------|
| `mpv-open.ps1` | The core script: parses the URL, appends to a running mpv or launches a new one. Works standalone from a terminal too. |
| `mpv-open.vbs` | Tiny wrapper that runs the script hidden (no console flash) when the browser triggers it. |
| `install.ps1` | Detects mpv/yt-dlp, writes `config.ps1`, and registers the `mpv:` URL protocol (per-user, no admin). |
| `uninstall.ps1` | Removes the protocol registration. |
| `config.example.ps1` | Documented list of settings. |
| `extension/` | The browser extension that adds the right-click **“Add to mpv”** menu item. |

## Requirements

- **Windows** with PowerShell 5.1+ (built in).
- **mpv** — you need the path to `mpv.exe`. Get it from <https://mpv.io/installation/> or `scoop install mpv`.
- **yt-dlp** — you already have this; keep `yt-dlp.exe` in the same folder as `mpv.exe` (mpv finds it automatically).
- A Chromium browser (**Chrome / Edge / Brave**) for the right-click menu. (Firefox notes below.)

## Install

1. **Get the files onto your PC** (clone or download this repo to a permanent
   location, e.g. `C:\Tools\mpv-autoopen`). Don't move the folder afterwards —
   the protocol registration points at these files by path. If you move it,
   re-run `install.ps1`.

2. **Run the installer.** Open PowerShell in this folder and run:

   ```powershell
   powershell -ExecutionPolicy Bypass -File .\install.ps1
   ```

   It auto-detects `mpv.exe` (common install locations + PATH) and the
   `yt-dlp.exe` next to it. If it can't find mpv, it asks for the path, or pass
   it explicitly:

   ```powershell
   powershell -ExecutionPolicy Bypass -File .\install.ps1 -MpvPath "D:\apps\mpv\mpv.exe"
   ```

   This writes `config.ps1` and registers the `mpv:` protocol for your user.

3. **Test without the browser** to confirm the core works:

   ```powershell
   .\mpv-open.ps1 "https://youtu.be/dQw4w9WgXcQ"
   ```

   mpv should open and start playing. Run it a second time with a different
   video — it should be **appended to the same window's playlist** (press
   `>` / `<` in mpv or `ENTER` to move between playlist entries).

4. **Load the browser extension:**
   - Go to `chrome://extensions` (or `edge://extensions`).
   - Turn on **Developer mode** (top-right).
   - Click **Load unpacked** and select the **`extension`** folder in this repo.

That's it.

## Usage

On any YouTube page:

- **Right-click a video thumbnail or title link** (homepage, search results,
  sidebar, a channel page…) → **“Add this YouTube video to mpv”**.
- **Right-click anywhere on a `/watch`, `/shorts/`, or `/live/` page** →
  **“Add this video to mpv”** (sends the video you're currently viewing).

The first time, your browser asks whether to open the external `mpv:` link —
allow it and tick **“Always allow”** so it won't ask again.

> **Right-clicking directly on the video player** shows YouTube's own menu, not
> the browser's, so use a thumbnail/title link or right-click an empty part of
> the page instead.

### Keeping one persistent mpv window

By default a new mpv window closes when its playlist finishes. If you'd rather
keep **one window alive** and just keep piling videos into it, edit `config.ps1`:

```powershell
$MpvExtraArgs = @('--idle=yes', '--keep-open=yes', '--force-window=immediate')
```

Now the window stays open (idle) after the last video, ready for the next
“Add to mpv”.

### Command-line use

`mpv-open.ps1` works on its own — no browser required:

```powershell
.\mpv-open.ps1 "https://www.youtube.com/watch?v=VIDEO_ID"
```

## Configuration (`config.ps1`)

`install.ps1` generates this for you; edit it any time. See
`config.example.ps1` for the full list. Key settings:

- `$MpvPath` — full path to `mpv.exe`.
- `$YtdlpPath` — full path to `yt-dlp.exe`, or `$null` to let mpv find it.
- `$PipeName` — the IPC pipe name used to reach a running instance.
- `$MpvExtraArgs` — extra args applied only when starting a **new** instance.

## How “add to my instance” works

When mpv-autoopen starts an mpv window it passes
`--input-ipc-server=\\.\pipe\mpv-autoopen`, opening a JSON IPC pipe. The next
time you add a video, the script connects to that pipe and sends
`loadfile <url> append-play`, which appends to the current playlist (and starts
playback if the window was idle). If the pipe isn't there (no instance, or one
you launched manually without the pipe), it just opens a fresh window.

## Troubleshooting

- **Nothing happens from the browser.** Check the log at
  `mpv-autoopen.log` in this folder — every request is recorded there. Also make
  sure you allowed the `mpv:` protocol prompt.
- **“mpv.exe not found”.** Set `$MpvPath` in `config.ps1` to the correct path
  (or re-run `install.ps1 -Force -MpvPath "..."`).
- **YouTube plays but fails after a while / with errors.** Update yt-dlp:
  `yt-dlp.exe -U` (run it from your mpv folder). Streaming breakage is almost
  always a stale yt-dlp.
- **`running scripts is disabled on this system`.** You launched PowerShell in a
  restricted policy. Use the `-ExecutionPolicy Bypass` form shown above; the
  protocol handler already runs with `-ExecutionPolicy Bypass`, so the browser
  path is unaffected.
- **A second instance opens instead of appending.** The existing window must
  have been started by this tool (so it has the IPC pipe). Windows you opened
  by other means don't have it. Also, clicking twice within the first second —
  before the first window's pipe is ready — can start a second one.

## Firefox

The extension is built for Chromium (MV3 service worker). Firefox needs a small
manifest change (`"background": { "scripts": ["background.js"] }`) and temporary
add-on loading via `about:debugging`. The `mpv:` protocol handler and
`mpv-open.ps1` are browser-agnostic and work the same.

## Uninstall

```powershell
powershell -ExecutionPolicy Bypass -File .\uninstall.ps1
```

Then remove the unpacked extension from `chrome://extensions`. Delete the folder
to remove `config.ps1` and the log.

## Security note

`mpv-open.ps1` only ever acts on `http(s)://` URLs and passes them to mpv/yt-dlp
— it doesn't execute the argument. Still, the `mpv:` protocol is reachable by
any page that builds such a link; that's inherent to custom URL protocols. The
worst a link can do is ask mpv to open a media URL.
