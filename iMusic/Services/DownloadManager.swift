import Foundation
import UIKit

enum DownloadStatus: Equatable {
    case notDownloaded
    case downloading(progress: Float)
    case downloaded
    case failed(String)
}

final class DownloadManager: NSObject, URLSessionDownloadDelegate {

    static let shared = DownloadManager()

    static let statusDidChangeNotification = Notification.Name("DownloadManagerStatusDidChange")
    static let listDidChangeNotification = Notification.Name("DownloadManagerListDidChange")

    private var downloadSession: URLSession!
    private var activeTasks: [String: URLSessionDownloadTask] = [:]
    private var taskTrackMap: [URLSessionDownloadTask: Track] = [:]
    private var progressMap: [String: Float] = [:]

    private let downloadsDirectory: URL
    private let manifestURL: URL
    private var downloadedTracksMap: [String: Track] = [:]

    override private init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.downloadsDirectory = docs.appendingPathComponent("Downloads", isDirectory: true)
        self.manifestURL = self.downloadsDirectory.appendingPathComponent("manifest.json")
        super.init()

        // Ensure downloads directory exists
        if !FileManager.default.fileExists(atPath: downloadsDirectory.path) {
            try? FileManager.default.createDirectory(at: downloadsDirectory, withIntermediateDirectories: true, attributes: nil)
        }

        loadManifest()

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 300
        self.downloadSession = URLSession(configuration: config, delegate: self, delegateQueue: OperationQueue.main)
    }

    // MARK: - Manifest Persistence

    private func loadManifest() {
        guard let data = try? Data(contentsOf: manifestURL),
              let list = try? JSONDecoder().decode([Track].self, from: data) else {
            return
        }
        for t in list {
            downloadedTracksMap[t.id] = t
        }
    }

    private func saveManifest() {
        let list = Array(downloadedTracksMap.values)
        if let data = try? JSONEncoder().encode(list) {
            try? data.write(to: manifestURL, options: .atomic)
        }
        NotificationCenter.default.post(name: DownloadManager.listDidChangeNotification, object: nil)
    }

    // MARK: - Query Status

    func status(for trackId: String) -> DownloadStatus {
        if downloadedTracksMap[trackId] != nil {
            let file = localAudioURL(for: trackId)
            if FileManager.default.fileExists(atPath: file.path) {
                return .downloaded
            }
        }
        if let prog = progressMap[trackId] {
            return .downloading(progress: prog)
        }
        return .notDownloaded
    }

    func isDownloaded(trackId: String) -> Bool {
        return status(for: trackId) == .downloaded
    }

    func allDownloadedTracks() -> [Track] {
        return Array(downloadedTracksMap.values).sorted { $0.title < $1.title }
    }

    func localAudioURL(for trackId: String) -> URL {
        return downloadsDirectory.appendingPathComponent("\(trackId).m4a")
    }

    func localArtworkURL(for trackId: String) -> URL {
        return downloadsDirectory.appendingPathComponent("\(trackId).jpg")
    }

    // MARK: - Download Operations

    func download(track: Track) {
        guard status(for: track.id) == .notDownloaded else { return }

        progressMap[track.id] = 0.05
        notifyStatus(trackId: track.id)

        // Resolve stream URL first
        StreamResolver.shared.resolveStreamURL(for: track) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                switch result {
                case .success(let streamURL):
                    let task = self.downloadSession.downloadTask(with: streamURL)
                    self.activeTasks[track.id] = task
                    self.taskTrackMap[task] = track
                    task.resume()

                    // Also cache artwork locally
                    if !track.artworkUrl.isEmpty {
                        ImageLoader.shared.loadImage(from: track.artworkUrl) { [weak self] img in
                            guard let self = self, let img = img,
                                  let data = img.jpegData(compressionQuality: 0.85) else { return }
                            let artURL = self.localArtworkURL(for: track.id)
                            try? data.write(to: artURL, options: .atomic)
                        }
                    }
                case .failure(let err):
                    self.progressMap.removeValue(forKey: track.id)
                    self.notifyStatus(trackId: track.id, errorMsg: err.localizedDescription)
                }
            }
        }
    }

    func downloadPlaylist(tracks: [Track]) {
        for t in tracks {
            if !isDownloaded(trackId: t.id) {
                download(track: t)
            }
        }
    }

    func cancelDownload(trackId: String) {
        if let task = activeTasks[trackId] {
            task.cancel()
            activeTasks.removeValue(forKey: trackId)
            taskTrackMap.removeValue(forKey: task)
        }
        progressMap.removeValue(forKey: trackId)
        notifyStatus(trackId: trackId)
    }

    func deleteDownload(trackId: String) {
        cancelDownload(trackId: trackId)
        downloadedTracksMap.removeValue(forKey: trackId)
        let audioFile = localAudioURL(for: trackId)
        let artFile = localArtworkURL(for: trackId)
        try? FileManager.default.removeItem(at: audioFile)
        try? FileManager.default.removeItem(at: artFile)
        saveManifest()
        notifyStatus(trackId: trackId)
    }

    private func notifyStatus(trackId: String, errorMsg: String? = nil) {
        NotificationCenter.default.post(
            name: DownloadManager.statusDidChangeNotification,
            object: nil,
            userInfo: ["trackId": trackId, "error": errorMsg ?? ""]
        )
    }

    // MARK: - URLSessionDownloadDelegate

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard let track = taskTrackMap[downloadTask] else { return }
        let progress: Float
        if totalBytesExpectedToWrite > 0 {
            progress = Float(totalBytesWritten) / Float(totalBytesExpectedToWrite)
        } else {
            progress = 0.5
        }
        progressMap[track.id] = progress
        notifyStatus(trackId: track.id)
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let track = taskTrackMap[downloadTask] else { return }

        let destination = localAudioURL(for: track.id)
        try? FileManager.default.removeItem(at: destination)

        do {
            try FileManager.default.moveItem(at: location, to: destination)
            var savedTrack = track
            savedTrack.streamUrl = destination.absoluteString
            downloadedTracksMap[track.id] = savedTrack
            saveManifest()

            progressMap.removeValue(forKey: track.id)
            activeTasks.removeValue(forKey: track.id)
            taskTrackMap.removeValue(forKey: downloadTask)
            notifyStatus(trackId: track.id)
        } catch {
            progressMap.removeValue(forKey: track.id)
            activeTasks.removeValue(forKey: track.id)
            taskTrackMap.removeValue(forKey: downloadTask)
            notifyStatus(trackId: track.id, errorMsg: error.localizedDescription)
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let downloadTask = task as? URLSessionDownloadTask,
              let track = taskTrackMap[downloadTask] else { return }

        if let err = error {
            progressMap.removeValue(forKey: track.id)
            activeTasks.removeValue(forKey: track.id)
            taskTrackMap.removeValue(forKey: downloadTask)
            notifyStatus(trackId: track.id, errorMsg: err.localizedDescription)
        }
    }
}
