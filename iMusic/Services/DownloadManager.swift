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

    private let lock = NSLock()
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
        lock.lock()
        defer { lock.unlock() }
        guard let data = try? Data(contentsOf: manifestURL),
              let list = try? JSONDecoder().decode([Track].self, from: data) else {
            return
        }
        for t in list {
            downloadedTracksMap[t.id] = t
        }
    }

    private func saveManifest() {
        let list: [Track]
        lock.lock()
        list = Array(downloadedTracksMap.values)
        lock.unlock()

        if let data = try? JSONEncoder().encode(list) {
            try? data.write(to: manifestURL, options: .atomic)
        }
        NotificationCenter.default.post(name: DownloadManager.listDidChangeNotification, object: nil)
    }

    // MARK: - Query Status

    func status(for trackId: String) -> DownloadStatus {
        lock.lock()
        defer { lock.unlock() }

        if downloadedTracksMap[trackId] != nil {
            let file = downloadsDirectory.appendingPathComponent("\(trackId).m4a")
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
        lock.lock()
        defer { lock.unlock() }
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

        lock.lock()
        progressMap[track.id] = 0.05
        lock.unlock()
        notifyStatus(trackId: track.id)

        // Resolve stream URL first
        StreamResolver.shared.resolveStreamURL(for: track) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                switch result {
                case .success(let streamURL):
                    let task = self.downloadSession.downloadTask(with: streamURL)
                    self.lock.lock()
                    self.activeTasks[track.id] = task
                    self.taskTrackMap[task] = track
                    self.lock.unlock()
                    task.resume()

                    // Directly download raw artwork without uncompressed bitmap in RAM
                    if let artUrl = URL(string: track.artworkUrl) {
                        URLSession.shared.dataTask(with: artUrl) { [weak self] artData, _, _ in
                            guard let self = self, let artData = artData else { return }
                            let artFile = self.localArtworkURL(for: track.id)
                            try? artData.write(to: artFile, options: .atomic)
                        }.resume()
                    }
                case .failure(let err):
                    self.lock.lock()
                    self.progressMap.removeValue(forKey: track.id)
                    self.lock.unlock()
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
        lock.lock()
        if let task = activeTasks[trackId] {
            task.cancel()
            activeTasks.removeValue(forKey: trackId)
            taskTrackMap.removeValue(forKey: task)
        }
        progressMap.removeValue(forKey: trackId)
        lock.unlock()
        notifyStatus(trackId: trackId)
    }

    func deleteDownload(trackId: String) {
        cancelDownload(trackId: trackId)

        lock.lock()
        downloadedTracksMap.removeValue(forKey: trackId)
        lock.unlock()

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
        lock.lock()
        guard let track = taskTrackMap[downloadTask] else {
            lock.unlock()
            return
        }
        let progress: Float = (totalBytesExpectedToWrite > 0) ? Float(totalBytesWritten) / Float(totalBytesExpectedToWrite) : 0.5
        progressMap[track.id] = progress
        lock.unlock()
        notifyStatus(trackId: track.id)
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        lock.lock()
        guard let track = taskTrackMap[downloadTask] else {
            lock.unlock()
            return
        }
        lock.unlock()

        // Validate HTTP response code (ensure not an error HTML page)
        if let httpResponse = downloadTask.response as? HTTPURLResponse,
           httpResponse.statusCode < 200 || httpResponse.statusCode >= 300 {
            try? FileManager.default.removeItem(at: location)
            lock.lock()
            progressMap.removeValue(forKey: track.id)
            activeTasks.removeValue(forKey: track.id)
            taskTrackMap.removeValue(forKey: downloadTask)
            lock.unlock()
            notifyStatus(trackId: track.id, errorMsg: "Server error \(httpResponse.statusCode)")
            return
        }

        // Validate downloaded file size (> 32 KB minimum for valid audio)
        if let attrs = try? FileManager.default.attributesOfItem(atPath: location.path),
           let size = attrs[.size] as? Int64, size < 32768 {
            try? FileManager.default.removeItem(at: location)
            lock.lock()
            progressMap.removeValue(forKey: track.id)
            activeTasks.removeValue(forKey: track.id)
            taskTrackMap.removeValue(forKey: downloadTask)
            lock.unlock()
            notifyStatus(trackId: track.id, errorMsg: "Incomplete file downloaded")
            return
        }

        let destination = localAudioURL(for: track.id)
        try? FileManager.default.removeItem(at: destination)

        do {
            try FileManager.default.moveItem(at: location, to: destination)
            var savedTrack = track
            savedTrack.streamUrl = destination.absoluteString

            lock.lock()
            downloadedTracksMap[track.id] = savedTrack
            progressMap.removeValue(forKey: track.id)
            activeTasks.removeValue(forKey: track.id)
            taskTrackMap.removeValue(forKey: downloadTask)
            lock.unlock()

            saveManifest()
            notifyStatus(trackId: track.id)
        } catch {
            lock.lock()
            progressMap.removeValue(forKey: track.id)
            activeTasks.removeValue(forKey: track.id)
            taskTrackMap.removeValue(forKey: downloadTask)
            lock.unlock()
            notifyStatus(trackId: track.id, errorMsg: error.localizedDescription)
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let downloadTask = task as? URLSessionDownloadTask else { return }
        lock.lock()
        guard let track = taskTrackMap[downloadTask] else {
            lock.unlock()
            return
        }
        if let err = error {
            progressMap.removeValue(forKey: track.id)
            activeTasks.removeValue(forKey: track.id)
            taskTrackMap.removeValue(forKey: downloadTask)
            lock.unlock()
            notifyStatus(trackId: track.id, errorMsg: err.localizedDescription)
        } else {
            lock.unlock()
        }
    }
}
