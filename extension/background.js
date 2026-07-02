// Add to mpv - right-click context menu that hands a YouTube URL to the
// local "mpv:" protocol handler (see ../mpv-open.ps1 + install.ps1).

// Links (thumbnails, sidebar, search results, etc.) that point at a video.
const VIDEO_LINK_PATTERNS = [
  "*://*.youtube.com/watch*",
  "*://*.youtube.com/shorts/*",
  "*://*.youtube.com/live/*",
  "*://youtu.be/*",
  "*://*.youtube-nocookie.com/*"
];

// Pages where "add THIS video" makes sense (a watch/shorts/live page).
const VIDEO_PAGE_PATTERNS = [
  "*://*.youtube.com/watch*",
  "*://*.youtube.com/shorts/*",
  "*://*.youtube.com/live/*",
  "*://youtu.be/*"
];

function buildMenus() {
  chrome.contextMenus.removeAll(() => {
    // Right-clicking a video *link* anywhere (e.g. a thumbnail on the homepage).
    chrome.contextMenus.create({
      id: "mpv-link",
      title: "Add this YouTube video to mpv",
      contexts: ["link"],
      targetUrlPatterns: VIDEO_LINK_PATTERNS
    });
    // Right-clicking the page/video while on a watch page.
    chrome.contextMenus.create({
      id: "mpv-page",
      title: "Add this video to mpv",
      contexts: ["page", "video"],
      documentUrlPatterns: VIDEO_PAGE_PATTERNS
    });
  });
}

chrome.runtime.onInstalled.addListener(buildMenus);
chrome.runtime.onStartup.addListener(buildMenus);

chrome.contextMenus.onClicked.addListener((info, tab) => {
  // Prefer the specific link that was clicked; else the current page URL.
  const url = info.linkUrl || info.pageUrl || (tab && tab.url);
  if (!url) return;

  // Single colon + fully percent-encoded payload keeps Windows from trying to
  // parse a "host" and keeps the command line free of spaces/quotes/&.
  const target = "mpv:" + encodeURIComponent(url);

  // Fire the OS handler from a throwaway background tab, then close it. This
  // never disturbs the YouTube page the user is on. The first time, the
  // browser asks permission to open the mpv: link (tick "Always allow").
  chrome.tabs.create({ url: target, active: false }, (t) => {
    void chrome.runtime.lastError;
    if (t && t.id != null) {
      setTimeout(() => chrome.tabs.remove(t.id, () => void chrome.runtime.lastError), 1000);
    }
  });
});
