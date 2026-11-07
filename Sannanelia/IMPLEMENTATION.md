# Sannanelia — implementation status

## Delivered in this iteration: Phase 1 browser foundation

- Native SwiftUI home, address editor, navigation controls and error views.
- Central semantic warm light/dark palette; System/Light/Dark preference in AppStorage.
- Stable, MainActor-isolated observable BrowserSession owning a WKWebView.
- Explicit navigation, back/forward, reload/stop, progress, current URL and title.
- HTTPS-first address recognition and five selectable search engines.
- Local input processing; no remote typing suggestions.
- Default WebKit certificate validation and platform ATS configuration.
- JavaScript alerts, confirmations and text prompts with site origin.
- User-confirmed mailto/tel/sms links; other non-web schemes are rejected.
- New-window web links open in the existing page in this single-session phase.
- Safe-area browser controls, Dynamic Type, VoiceOver labels, Reduce Motion-aware progress.
- System-selected English/German String Catalog localization.
- Command-L, Command-R and back/forward keyboard shortcuts.

The original app entry point and target configuration are retained. The minimum
deployment target is iOS/iPadOS 27.0; development uses the installed iOS 27.2 SDK.

## Remaining phases

### Phase 2 — tabs
BrowserTabManager, stable tab IDs, tab grid, separate private sessions using
nonpersistent website stores, tab lifecycle/memory policy, closed-tab restoration,
normal-tab persistence. Current implementation has one normal session per window.

### Phase 3 — persistent browser data
SwiftData models and data service, bookmark CRUD/reordering, searchable and
date-grouped history, local address suggestions and explicit website-data deletion.

### Phase 4 — browser extensions
WKDownload manager and file export, download records/progress, find-in-page,
desktop/mobile mode, richer browser menu, favicon handling and upload verification.
Non-displayable responses currently produce an explanatory error.

### Phase 5 — complete settings and validation
In-app language override, configured homepage, restoration preferences, JavaScript
settings, TipKit, dedicated Swift Testing/XCUIAutomation targets, accessibility
audits, multiwindow persistence ownership and App Store/privacy release review.

## Verification

Xcode BuildProject succeeded for the browser foundation. Runtime snippets verify
HTTPS normalization, blocked executable/file input, malformed addresses, all five
search engines including ampersands/plus signs/Unicode, and stable WebView identity.
Simulator UI verification is tracked in the task report. A successful build alone
does not establish exhaustive WebKit, accessibility or device coverage.
