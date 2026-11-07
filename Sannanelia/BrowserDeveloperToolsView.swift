//
//  BrowserDeveloperToolsView.swift
//  Sannanelia
//
//  Created by Tufan Cakir on 07.11.26.
//

import SwiftUI

struct BrowserDeveloperToolsView: View {
    let session: BrowserSession

    var body: some View {
        NavigationStack {
            List {
                Section("Developer Tools") {
                    NavigationLink {
                        BrowserJavaScriptView(session: session)
                    } label: {
                        Label(
                            "JavaScript Console",
                            systemImage:
                                "chevron.left.forwardslash.chevron.right"
                        )
                    }

                    NavigationLink {
                        BrowserHTMLSourceView(session: session)
                    } label: {
                        Label(
                            "HTML Source",
                            systemImage:
                                "chevron.left.forwardslash.chevron.right"
                        )
                    }
                }
            }
            .navigationTitle("Developer Tools")
        }
    }
}
