//
//  BrowserPDFExport.swift
//  Sannanelia
//
//  Created by Tufan Cakir on 07.11.26.
//

import Foundation

enum BrowserPDFExport {
    @MainActor
    static func createFile(
        from session: BrowserSession
    ) async throws -> URL {
        let data = try await session.createPDF()

        let directory = FileManager.default.temporaryDirectory
        let filename = "Sannanelia-\(UUID().uuidString).pdf"
        let url = directory.appendingPathComponent(filename)

        try data.write(to: url, options: .atomic)

        return url
    }
}
