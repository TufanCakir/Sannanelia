//
//  BrowserVideoDownloadOverlay.swift
//  Sannanelia
//
//  Created by Tufan Cakir on 08.11.26.
//

import SwiftUI

struct BrowserVideoDownloadOverlay: View {
    let video: BrowserDetectedVideo
    let download: () -> Void
    let cancel: () -> Void
    let canDownload: Bool

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "play.rectangle.fill")
                .font(.system(size: 36))
                .foregroundStyle(.tint)

            Text("Video erkannt")
                .font(.headline)

            Text(video.title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)

            Text(
                canDownload
                    ? "Möchtest du dieses Video herunterladen?"
                    : "Für dieses Video ist kein direkter Download verfügbar."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)

            HStack(spacing: 12) {
                Button("Abbrechen", role: .cancel) {
                    cancel()
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)

                Button {
                    download()
                } label: {
                    Label("Download", systemImage: "arrow.down")
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canDownload)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(24)
        .frame(maxWidth: 360)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
        .shadow(radius: 16)
        .padding()
    }
}
