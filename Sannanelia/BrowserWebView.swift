//
//  BrowserWebView.swift
//  Sannanelia
//
//  Created by Tufan Cakir on 07.11.26.
//

import SwiftUI
import WebKit

struct BrowserWebView: UIViewRepresentable {
    let session: BrowserSession

    func makeUIView(context: Context) -> WKWebView {
        session.webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        // UIKit accessibility must also be updated for WebKit's remote content tree.
        uiView.accessibilityElementsHidden =
            session.isHome || session.failure != nil
        // Navigation is explicit in BrowserSession, never caused by body evaluation.
    }
}
