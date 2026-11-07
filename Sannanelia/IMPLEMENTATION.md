# Sannanelia — current implementation status

## Implemented

- Native SwiftUI browser chrome, home, address entry, progress and themed error views.
- Stable WKWebView per active tab; back/forward, reload/stop, JavaScript dialogs,
  new-window links, standard certificate validation and local URL/search parsing.
- Ten search engines, including the five originally requested. Plus signs,
  ampersands and Unicode are preserved in submitted queries.
- Normal/private tab grid, duplicate/close/restore-closed actions, per-window normal
  tab persistence and lazy restoration. Idle runtime sessions can be suspended.
- Private tabs use nonpersistent WebKit stores, never write history or tab models,
  and clear their runtime/console state when closed or the window detaches.
- SwiftData bookmarks with editing/reordering/search and history grouped by day.
  Bookmark/history suggestions are local; homepage shows favorites/frequent visits.
- WKDownload delegate integration, progress, status, cancellation, deletion and
  share/export. Private download files are temporary and removed at session end.
- Find-in-page, desktop/mobile mode, copy/share URL and working browser menu.
- AppStorage preferences for appearance, language, search, homepage, normal-tab
  restoration and JavaScript. Cookie/cache/site-data deletion is separate from history.
- Existing onboarding, HTML/DOM inspection, JavaScript console/editor and PDF
  export additions were preserved.
- English/German String Catalogs; translation completion is checked separately.
- iPhone/iPad target, minimum iOS 27.0, installed SDK iOS 27.2.

## Automated verification

Use the **SannaneliaTests** scheme to run the Swift Testing suite. The app scheme
remains **Sannanelia**. Build the app before running the standalone test scheme.
The test bundle is hosted by Sannanelia; the app uses a standard executable debug
build (ENABLE_DEBUG_DYLIB=NO) so the standalone test bundle can link app symbols.

Latest executed suite: **23 passed, 0 failed** (8 test functions including
parameterized cases). Coverage:

- All ten search engines preserve special characters with correct parameter names.
- Unsafe/malformed address input is rejected; addresses default to HTTPS.
- Invalid navigation presents the browser error state.
- Private data-store isolation, no persisted private tabs/history, session teardown.
- WebView identity across tab selection and restoration of normal/closed tabs.
- Private tabs and console contents are discarded when a window detaches.
- Bookmark/history deduplication and independent history deletion.

The app also builds successfully with no issues in Xcode's issue navigator.

## Remaining validation and polish

This is not a declaration of App Store readiness. Still outstanding:

- End-to-end download/file-export/upload, media/fullscreen and JavaScript-dialog
  coverage on physical devices.
- Dedicated XCUIAutomation regression tests; exhaustive VoiceOver, Dynamic Type,
  contrast, Reduce Motion, iPad multitasking and multiwindow lifecycle checks.
- Favicons, optional tab previews and TipKit polish.
- Release app icon, distribution signing, privacy publication/App Store metadata.

A successful build and the tests above do not establish coverage of these remaining
items. Normal-tab restoration restores page URLs, not WebKit's full back-forward
history; suspended tabs may reload.
