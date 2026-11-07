import Foundation
import Observation
import SwiftData
import WebKit

@MainActor @Observable
final class BrowserDownloadItem: Identifiable {
    enum Status: String {
        case downloading, finished, failed, cancelled
        var title: LocalizedStringResource {
            switch self {
            case .downloading: "Downloading"
            case .finished: "Ready"
            case .failed: "Download failed"
            case .cancelled: "Cancelled"
            }
        }
    }

    let id: UUID
    let isPrivate: Bool
    var filename: String
    var fileURL: URL?
    var status: Status
    var fractionCompleted = 0.0
    var totalBytes: Int64 = 0

    init(id: UUID = UUID(), isPrivate: Bool, filename: String = "", status: Status = .downloading) {
        self.id = id
        self.isPrivate = isPrivate
        self.filename = filename
        self.status = status
    }
}

@MainActor @Observable
final class BrowserDownloadManager: NSObject, WKDownloadDelegate {
    private(set) var items: [BrowserDownloadItem] = []
    var storageError = false
    @ObservationIgnored private var context: ModelContext?
    @ObservationIgnored private var active: [ObjectIdentifier: (WKDownload, BrowserDownloadItem)] = [:]
    @ObservationIgnored private var observations: [ObjectIdentifier: NSKeyValueObservation] = [:]
    @ObservationIgnored private let privateRoot = FileManager.default.temporaryDirectory
        .appending(path: "SannaneliaPrivateDownloads", directoryHint: .isDirectory)
        .appending(path: UUID().uuidString, directoryHint: .isDirectory)

    static var root: URL {
        URL.applicationSupportDirectory.appending(path: "Downloads", directoryHint: .isDirectory)
    }

    func configure(_ context: ModelContext) {
        guard self.context == nil else { return }
        self.context = context
        do {
            let records = try context.fetch(FetchDescriptor<DownloadRecord>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)]))
            items = records.map { record in
                let status = BrowserDownloadItem.Status(rawValue: record.status) ?? .failed
                let item = BrowserDownloadItem(id: record.id, isPrivate: false, filename: record.filename,
                                               status: status == .downloading ? .failed : status)
                item.fileURL = Self.root.appending(path: record.relativePath)
                if status == .finished, let url = item.fileURL, !FileManager.default.fileExists(atPath: url.path) {
                    item.status = .failed
                }
                return item
            }
        } catch { storageError = true }
    }

    func register(_ download: WKDownload, isPrivate: Bool) {
        let item = BrowserDownloadItem(isPrivate: isPrivate)
        items.insert(item, at: 0)
        let key = ObjectIdentifier(download)
        active[key] = (download, item)
        download.delegate = self
        observations[key] = download.progress.observe(\.fractionCompleted, options: [.initial, .new]) { [weak self] _, _ in
            Task { @MainActor [weak self] in
                guard let pair = self?.active[key] else { return }
                pair.1.fractionCompleted = pair.0.progress.fractionCompleted
                pair.1.totalBytes = pair.0.progress.totalUnitCount
            }
        }
    }

    func download(_ download: WKDownload, decideDestinationUsing response: URLResponse,
                  suggestedFilename: String, completionHandler: @escaping (URL?) -> Void) {
        guard let item = active[ObjectIdentifier(download)]?.1 else { completionHandler(nil); return }
        let proposed = (suggestedFilename as NSString).lastPathComponent
        let filename = proposed.isEmpty || proposed == "." || proposed == ".." ? "Download" : proposed
        let folder = (item.isPrivate ? privateRoot : Self.root)
            .appending(path: item.id.uuidString, directoryHint: .isDirectory)
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let destination = folder.appending(path: filename, directoryHint: .notDirectory)
            item.filename = filename
            item.fileURL = destination
            save(item)
            completionHandler(destination)
        } catch {
            item.status = .failed
            storageError = true
            completionHandler(nil)
        }
    }

    func downloadDidFinish(_ download: WKDownload) {
        guard let item = active[ObjectIdentifier(download)]?.1 else { return }
        item.status = .finished
        item.fractionCompleted = 1
        save(item)
        finish(download)
    }

    func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
        guard let item = active[ObjectIdentifier(download)]?.1 else { return }
        item.status = .failed
        save(item)
        finish(download)
    }

    private func finish(_ download: WKDownload) {
        let key = ObjectIdentifier(download)
        observations.removeValue(forKey: key)
        active.removeValue(forKey: key)
        download.delegate = nil
    }

    func cancel(_ item: BrowserDownloadItem) {
        if let pair = active.values.first(where: { $0.1.id == item.id }) {
            finish(pair.0)
            pair.0.cancel { _ in }
        }
        item.status = .cancelled
        save(item)
    }

    func delete(_ item: BrowserDownloadItem) {
        if item.status == .downloading { cancel(item) }
        do {
            if let url = item.fileURL, FileManager.default.fileExists(atPath: url.deletingLastPathComponent().path) {
                try FileManager.default.removeItem(at: url.deletingLastPathComponent())
            }
            if !item.isPrivate, let context {
                let id = item.id
                if let record = try context.fetch(FetchDescriptor<DownloadRecord>(predicate: #Predicate { $0.id == id })).first {
                    context.delete(record)
                    try context.save()
                }
            }
            items.removeAll { $0.id == item.id }
        } catch { storageError = true }
    }

    func endPrivateSession() {
        let privateItems = items.filter(\.isPrivate)
        for item in privateItems { delete(item) }
        do {
            if FileManager.default.fileExists(atPath: privateRoot.path) {
                try FileManager.default.removeItem(at: privateRoot)
            }
        } catch { storageError = true }
    }

    private func save(_ item: BrowserDownloadItem) {
        guard !item.isPrivate, let context, let fileURL = item.fileURL else { return }
        do {
            let id = item.id
            if let record = try context.fetch(FetchDescriptor<DownloadRecord>(predicate: #Predicate { $0.id == id })).first {
                record.status = item.status.rawValue
            } else {
                context.insert(DownloadRecord(id: item.id, filename: item.filename,
                                              relativePath: item.id.uuidString + "/" + fileURL.lastPathComponent,
                                              status: item.status.rawValue))
            }
            try context.save()
        } catch {
            context.rollback()
            storageError = true
        }
    }
}
