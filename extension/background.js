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

// Runs INSIDE the YouTube page: click a real <a href="mpv:..."> link. A genuine
// in-page anchor click is what reliably makes the browser hand the URL to the
// OS protocol handler; it does not navigate or reload the page. (Opening a
// background tab, by contrast, gets its external-app launch suppressed by
// Chrome -- that was the bug where a blank window flashed and nothing ran.)
function clickMpvLink(target) {
  const a = document.createElement("a");
  a.href = target;
  a.style.display = "none";
  (document.body || document.documentElement).appendChild(a);
  a.click();
  a.remove();
}

chrome.contextMenus.onClicked.addListener((info, tab) => {
  // Prefer the specific link that was clicked; else the current page URL.
  const url = info.linkUrl || info.pageUrl;
  if (!url || !tab || tab.id == null) return;

  // Single colon + fully percent-encoded payload keeps Windows from trying to
  // parse a "host" and keeps the command line free of spaces/quotes/&.
  const target = "mpv:" + encodeURIComponent(url);

  // "scripting" + "activeTab" (granted by the context-menu click) let us inject
  // the click into the current tab without any broad host permissions.
  chrome.scripting.executeScript({
    target: { tabId: tab.id },
    func: clickMpvLink,
    args: [target]
  }).catch(() => {
    // Fallback for older engines: navigate the active tab to the scheme. The
    // external handler fires and the page stays put.
    chrome.tabs.update(tab.id, { url: target }, () => void chrome.runtime.lastError);
  });
});
