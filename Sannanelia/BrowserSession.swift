//

//  BrowserSession.swift

//  Sannanelia

//

//  Created by Tufan Cakir on 07.11.26.

//

import Foundation
import Observation
import WebKit

enum BrowserFailure {

    case invalidAddress, offline, secureConnection, unavailable,

        processTerminated

    var title: LocalizedStringResource {

        switch self {

        case .invalidAddress: "Invalid address"

        case .offline: "You are offline"

        case .secureConnection: "Secure connection failed"

        case .unavailable: "This website is unavailable"

        case .processTerminated: "This page needs to reload"

        }

    }

    var message: LocalizedStringResource {

        switch self {

        case .invalidAddress: "Enter a website address or a search term."

        case .offline: "Check your internet connection and try again."

        case .secureConnection:

            "The website could not establish a trusted connection. Your security settings have not been changed."

        case .unavailable:

            "The server could not load this page. Please try again."

        case .processTerminated:

            "WebKit released this page to free resources. Reload to continue."

        }

    }

}

struct BrowserScriptDialog: Identifiable {

    enum Kind { case alert, confirm, prompt }

    let id = UUID()

    let kind: Kind

    let host: String

    let message: String

    let defaultText: String

    let completion: (String?) -> Void

}

/// Owns one stable web view independently of SwiftUI view updates.

/// This session becomes the per-tab runtime object in the tab implementation.

@MainActor @Observable

final class BrowserSession: NSObject, WKNavigationDelegate, WKUIDelegate {

    @ObservationIgnored let webView: WKWebView

    @ObservationIgnored private var observations: [NSKeyValueObservation] = []

    var url: URL?

    var title = ""

    var progress = 0.0

    var isLoading = false

    var canGoBack = false

    var canGoForward = false

    var hasSecureContent = false

    var isHome = true

    var failure: BrowserFailure?

    var dialog: BrowserScriptDialog?

    var externalURL: URL?

    @ObservationIgnored private var requestedURL: URL?

    @ObservationIgnored var onPageFinished: ((URL, String) -> Void)?

    @ObservationIgnored var onStateChanged: (() -> Void)?

    @ObservationIgnored var onCreateWindow:

        ((WKWebViewConfiguration) -> WKWebView?)?

    override convenience init() {

        self.init(dataStore: .default())

    }

    convenience init(dataStore: WKWebsiteDataStore) {

        let configuration = WKWebViewConfiguration()

        configuration.websiteDataStore = dataStore

        self.init(configuration: configuration)

    }

    init(configuration: WKWebViewConfiguration) {

        // MARK: - WebKit Configuration

        configuration.userContentController = WKUserContentController()

        configuration.allowsInlineMediaPlayback = true

        configuration.preferences.isElementFullscreenEnabled = true

        // MARK: - JavaScript Console Bridge

        let store = BrowserConsoleStore()

        let bridge = BrowserConsoleBridge(store: store)

        let controller = configuration.userContentController

        // MARK: - Video Detection

        controller.add(

            bridge,

            contentWorld: .page,

            name: "sannaneliaConsole"

        )

        controller.addUserScript(

            WKUserScript(

                source: BrowserConsoleScript.source,

                injectionTime: .atDocumentStart,

                forMainFrameOnly: false,

                in: .page

            )

        )

        // MARK: - Stored Properties

        self.consoleStore = store

        self.consoleBridge = bridge

        self.webView = WKWebView(

            frame: .zero,

            configuration: configuration

        )

        super.init()

        // MARK: - WebView Setup

        webView.navigationDelegate = self

        webView.uiDelegate = self

        webView.allowsBackForwardNavigationGestures = true

        // MARK: - KVO Observations

        observations = [
            webView.observe(\.estimatedProgress, options: [.new]) {
                [weak self] _, _ in
                Task { @MainActor [weak self] in
                    self?.synchronize()
                }
            },

            webView.observe(\.isLoading, options: [.new]) {
                [weak self] _, _ in
                Task { @MainActor [weak self] in
                    self?.synchronize()
                }
            },

            webView.observe(\.url, options: [.new]) {
                [weak self] _, _ in
                Task { @MainActor [weak self] in
                    self?.synchronize()
                }
            },

            webView.observe(\.title, options: [.new]) {
                [weak self] _, _ in
                Task { @MainActor [weak self] in
                    self?.synchronize()
                }
            },

            webView.observe(\.canGoBack, options: [.new]) {
                [weak self] _, _ in
                Task { @MainActor [weak self] in
                    self?.synchronize()
                }
            },

            webView.observe(\.canGoForward, options: [.new]) {
                [weak self] _, _ in
                Task { @MainActor [weak self] in
                    self?.synchronize()
                }
            },

            webView.observe(\.hasOnlySecureContent, options: [.new]) {
                [weak self] _, _ in
                Task { @MainActor [weak self] in
                    self?.synchronize()
                }
            },
        ]
    }

    @ObservationIgnored

    let consoleStore: BrowserConsoleStore

    @ObservationIgnored

    private let consoleBridge: BrowserConsoleBridge

    func createPDF() async throws -> Data {

        let configuration = WKPDFConfiguration()

        return try await webView.pdf(

            configuration: configuration

        )

    }

    func executeJavaScript(_ script: String) async throws -> Any? {

        try await webView.evaluateJavaScript(script)

    }

    func getHTMLSource() async throws -> String {

        let result = try await webView.evaluateJavaScript(

            "document.documentElement.outerHTML"

        )

        guard let html = result as? String, !html.isEmpty else {

            throw NSError(

                domain: "Sannanelia.HTML",

                code: 1,

                userInfo: [

                    NSLocalizedDescriptionKey: "No HTML source available."

                ]

            )

        }

        return html

    }

    func getDOMTree() async throws -> [HTMLNode] {

        let script = #"""

            (() => {

                let nextID = 0;

                const maxNodes = 3000;

                const maxDepth = 60;

                function readNode(element, depth) {

                    if (nextID >= maxNodes) return null;

                    const id = nextID++;

                    const name = element.tagName.toLowerCase();

                    const attributes = Array.from(element.attributes)

                        .slice(0, 8)

                        .map(attribute => {

                            const value = attribute.value

                                .slice(0, 100)

                                .replace(/"/g, '"');

                            return ` ${attribute.name}="${value}"`;

                        })

                        .join('');

                    const children = [];

                    if (depth < maxDepth) {

                        for (const child of element.children) {

                            if (nextID >= maxNodes) break;

                            const result = readNode(child, depth + 1);

                            if (result !== null) {

                                children.push(result);

                            }

                        }

                    }

                    return {

                        id,

                        name,

                        attributes,

                        children: children.length > 0 ? children : null

                    };

                }

                const root = document.documentElement;

                return JSON.stringify(

                    root ? [readNode(root, 0)] : []

                );

            })()

            """#

        let result = try await webView.evaluateJavaScript(script)

        guard let json = result as? String,

            let data = json.data(using: .utf8)

        else {

            throw NSError(

                domain: "Sannanelia.DOM",

                code: 1,

                userInfo: [

                    NSLocalizedDescriptionKey:

                        "Unable to read the DOM tree."

                ]

            )

        }

        return try JSONDecoder().decode([HTMLNode].self, from: data)

    }

    private func synchronize() {

        url = webView.url

        title = webView.title ?? ""

        progress = webView.estimatedProgress

        isLoading = webView.isLoading

        canGoBack = webView.canGoBack

        canGoForward = webView.canGoForward

        hasSecureContent =

            webView.url?.scheme == "https" && webView.hasOnlySecureContent

    }

    func navigate(_ input: String, engine: BrowserSearchEngine) {

        guard

            let url = BrowserSearchService.destination(

                for: input,

                engine: engine

            )

        else {

            webView.stopLoading()

            isHome = false

            failure = .invalidAddress

            return

        }

        load(url)

    }

    func load(_ destination: URL) {

        finishDialog(nil)

        requestedURL = destination

        isHome = false

        failure = nil

        url = destination

        webView.load(URLRequest(url: destination))

        onStateChanged?()

    }

    var desktopMode = UserDefaults.standard.bool(forKey: "desktopDefault")

    func goHome() {

        let homepage = UserDefaults.standard.string(forKey: "homepage") ?? ""

        if homepage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {

            home()

        } else {

            navigate(homepage, engine: .duckDuckGo)

        }

    }

    func home() {

        finishDialog(nil)

        webView.stopLoading()

        failure = nil

        isHome = true

        onStateChanged?()

    }

    func close() {

        consoleStore.clear()

        externalURL = nil

        finishDialog(nil)

        webView.stopLoading()

        webView.navigationDelegate = nil

        webView.uiDelegate = nil

        observations.removeAll()

        onPageFinished = nil

        onStateChanged = nil

        onCreateWindow = nil

        webView.configuration.userContentController

            .removeScriptMessageHandler(

                forName: "sannaneliaConsole",

                contentWorld: .page

            )

    }

    func back() {

        failure = nil

        if isHome, webView.url != nil {

            isHome = false

        } else {

            webView.goBack()

        }

    }

    func forward() {

        isHome = false

        failure = nil

        webView.goForward()

    }

    func reload() {

        failure = nil

        isHome = false

        if let requestedURL {

            if webView.url == requestedURL {

                webView.reload()

            } else {

                webView.load(URLRequest(url: requestedURL))

            }

        }

    }

    func finishDialog(_ response: String?) {

        guard let current = dialog else { return }

        dialog = nil

        current.completion(response)

    }

    func webView(

        _ webView: WKWebView,

        didStartProvisionalNavigation navigation: WKNavigation!

    ) {

        failure = nil

        synchronize()

    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {

        requestedURL = webView.url

        synchronize()

    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {

        synchronize()

        if let url = webView.url { onPageFinished?(url, title) }

    }

    private func handle(_ error: Error) {

        let error = error as NSError

        guard

            !(error.domain == NSURLErrorDomain

                && error.code == NSURLErrorCancelled)

        else { return }

        if let failing = error.userInfo[NSURLErrorFailingURLErrorKey] as? URL {

            requestedURL = failing

        }

        if error.domain == NSURLErrorDomain {

            switch error.code {

            case NSURLErrorNotConnectedToInternet,

                NSURLErrorNetworkConnectionLost:

                failure = .offline

            case NSURLErrorSecureConnectionFailed,

                NSURLErrorServerCertificateUntrusted,

                NSURLErrorServerCertificateHasBadDate,

                NSURLErrorServerCertificateHasUnknownRoot,

                NSURLErrorServerCertificateNotYetValid,

                NSURLErrorClientCertificateRejected,

                NSURLErrorClientCertificateRequired:

                failure = .secureConnection

            default: failure = .unavailable

            }

        } else {

            failure = .unavailable

        }

        synchronize()

    }

    func webView(

        _ webView: WKWebView,

        didFail navigation: WKNavigation!,

        withError error: Error

    ) {

        handle(error)

    }

    func webView(

        _ webView: WKWebView,

        didFailProvisionalNavigation navigation: WKNavigation!,

        withError error: Error

    ) {

        handle(error)

    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {

        finishDialog(nil)

        failure = .processTerminated

        synchronize()

    }

    func webView(

        _ webView: WKWebView,

        didReceive challenge: URLAuthenticationChallenge,

        completionHandler:

            @escaping (URLSession.AuthChallengeDisposition, URLCredential?) ->

            Void

    ) {

        // Never bypass trust evaluation or accept an invalid certificate.

        completionHandler(.performDefaultHandling, nil)

    }

    func webView(

        _ webView: WKWebView,

        decidePolicyFor navigationAction: WKNavigationAction,

        preferences: WKWebpagePreferences,

        decisionHandler:

            @escaping (WKNavigationActionPolicy, WKWebpagePreferences) -> Void

    ) {

        preferences.allowsContentJavaScript =

            UserDefaults.standard.object(forKey: "javaScript") as? Bool ?? true

        preferences.preferredContentMode = desktopMode ? .desktop : .mobile

        policy(for: navigationAction) { policy in

            decisionHandler(policy, preferences)

        }

    }

    private func policy(
        for navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        guard let destination = navigationAction.request.url,
            let scheme = destination.scheme?.lowercased()
        else {
            decisionHandler(.cancel)
            return
        }

        switch scheme {
        case "http", "https", "about", "blob":
            // Keep standard website navigation inside Sannanelia.
            // Links opening a new window are handled by WKUIDelegate below.
            decisionHandler(.allow)

        case "mailto", "tel", "sms":
            // Only explicitly tapped links may ask to open another app.
            if navigationAction.navigationType == .linkActivated,
                navigationAction.targetFrame?.isMainFrame != false
            {
                externalURL = destination
            }
            decisionHandler(.cancel)

        default:
            // Block custom app schemes (youtube:, intent:, etc.).
            decisionHandler(.cancel)
        }
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationResponse: WKNavigationResponse,
        decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void
    ) {
        // Display only content that WebKit supports; no download feature.
        decisionHandler(navigationResponse.canShowMIMEType ? .allow : .cancel)
    }

    func setDesktopMode(_ enabled: Bool) {

        desktopMode = enabled

        reload()

    }

    func webView(

        _ webView: WKWebView,

        createWebViewWith configuration: WKWebViewConfiguration,

        for navigationAction: WKNavigationAction,

        windowFeatures: WKWindowFeatures

    ) -> WKWebView? {

        guard navigationAction.targetFrame == nil,

            let url = navigationAction.request.url,

            ["http", "https"].contains(url.scheme?.lowercased() ?? "")

        else {

            return nil

        }

        load(url)

        return nil

    }

    func webView(

        _ webView: WKWebView,

        runJavaScriptAlertPanelWithMessage message: String,

        initiatedByFrame frame: WKFrameInfo,

        completionHandler: @escaping () -> Void

    ) {

        finishDialog(nil)

        dialog = BrowserScriptDialog(

            kind: .alert,

            host: frame.securityOrigin.host,

            message: message,

            defaultText: ""

        ) { _ in completionHandler() }

    }

    func webView(

        _ webView: WKWebView,

        runJavaScriptConfirmPanelWithMessage message: String,

        initiatedByFrame frame: WKFrameInfo,

        completionHandler: @escaping (Bool) -> Void

    ) {

        finishDialog(nil)

        dialog = BrowserScriptDialog(

            kind: .confirm,

            host: frame.securityOrigin.host,

            message: message,

            defaultText: ""

        ) { completionHandler($0 != nil) }

    }

    func webView(

        _ webView: WKWebView,

        runJavaScriptTextInputPanelWithPrompt prompt: String,

        defaultText: String?,

        initiatedByFrame frame: WKFrameInfo,

        completionHandler: @escaping (String?) -> Void

    ) {

        finishDialog(nil)

        dialog = BrowserScriptDialog(

            kind: .prompt,

            host: frame.securityOrigin.host,

            message: prompt,

            defaultText: defaultText ?? "",

            completion: completionHandler

        )

    }

}
