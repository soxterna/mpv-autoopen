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
  const url = info.linkUrl || info.pageUrl;
  if (!url || !tab || tab.id == null) return;

  // Single colon + fully percent-encoded payload keeps Windows from trying to
  // parse a "host" and keeps the command line free of spaces/quotes/&.
  const target = "mpv:" + encodeURIComponent(url);

  // Navigate the CURRENT tab to the mpv: URL. This is exactly what typing the
  // URL into the address bar does (which is confirmed working): the browser
  // hands the URL to the registered OS handler and, because a handler exists,
  // cancels the navigation -- so the YouTube page is NOT reloaded or replaced.
  //
  // Why not the previous tricks? An unfocused background tab has its
  // external-app launch suppressed by Chrome, and a programmatically injected
  // in-page click lacks the user activation Chrome requires -- both silently
  // did nothing. A top-level navigation of the active tab does not.
  chrome.tabs.update(tab.id, { url: target }, () => void chrome.runtime.lastError);
});
