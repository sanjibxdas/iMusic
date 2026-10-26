import Foundation

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

    private struct Job {
        let track: Track
        let generation: UUID
    }

    private struct Manifest: Codable {
        let tracks: [Track]
        let fileNames: [String: String]
    }

    private let downloadsDirectory: URL
    private let manifestURL: URL
    private var downloadSession: URLSession!
    private var pending: [Job] = []
    private var generations: [String: UUID] = [:]
    private var running: [String: UUID] = [:]
    private var tasks: [String: URLSessionDownloadTask] = [:]
    private var taskJobs: [Int: Job] = [:]
    private var progress: [String: Float] = [:]
    private var failures: [String: String] = [:]
    private var tracks: [String: Track] = [:]
    private var fileNames: [String: String] = [:]

    private override init() {
        downloadsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Downloads", isDirectory: true)
        manifestURL = downloadsDirectory.appendingPathComponent("manifest.json")
        super.init()
        try? FileManager.default.createDirectory(at: downloadsDirectory, withIntermediateDirectories: true, attributes: nil)
        loadManifest()
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 900
        configuration.httpMaximumConnectionsPerHost = 2
        downloadSession = URLSession(configuration: configuration, delegate: self, delegateQueue: .main)
    }

    // Delegate callbacks and all mutable state share the main queue.
    private func onMain<T>(_ body: () -> T) -> T {
        if Thread.isMainThread { return body() }
        return DispatchQueue.main.sync(execute: body)
    }

    private func loadManifest() {
        guard let data = try? Data(contentsOf: manifestURL) else { return }
        let decodedTracks: [Track]
        if let manifest = try? JSONDecoder().decode(Manifest.self, from: data) {
            decodedTracks = manifest.tracks
            fileNames = manifest.fileNames.filter { _, name in
                name == (name as NSString).lastPathComponent &&
                    ["m4a", "aac", "mp3"].contains((name as NSString).pathExtension.lowercased())
            }
        } else if let legacy = try? JSONDecoder().decode([Track].self, from: data) {
            decodedTracks = legacy
        } else { return }
        for var track in decodedTracks {
            track.streamUrl = nil
            if FileManager.default.fileExists(atPath: audioURL(for: track.id).path) {
                tracks[track.id] = track
            }
        }
    }

    private func persistManifest() throws {
        let manifest = Manifest(tracks: Array(tracks.values), fileNames: fileNames)
        try JSONEncoder().encode(manifest).write(to: manifestURL, options: .atomic)
    }

    private func safeStem(_ id: String) -> String {
        return Data(id.utf8).base64EncodedString()
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "=", with: "")
    }

    private func audioURL(for id: String) -> URL {
        if let name = fileNames[id] { return downloadsDirectory.appendingPathComponent(name) }
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-")
        if !id.isEmpty && id.unicodeScalars.allSatisfy({ allowed.contains($0) }) {
            let legacy = downloadsDirectory.appendingPathComponent(id + ".m4a")
            if FileManager.default.fileExists(atPath: legacy.path) { return legacy }
        }
        return downloadsDirectory.appendingPathComponent(safeStem(id) + ".m4a")
    }

    func localAudioURL(for trackId: String) -> URL {
        return onMain { audioURL(for: trackId) }
    }

    func localArtworkURL(for trackId: String) -> URL {
        return downloadsDirectory.appendingPathComponent(safeStem(trackId) + ".jpg")
    }

    func status(for trackId: String) -> DownloadStatus {
        return onMain {
            if tracks[trackId] != nil && FileManager.default.fileExists(atPath: audioURL(for: trackId).path) {
                return .downloaded
            }
            if let value = progress[trackId] { return .downloading(progress: value) }
            if let message = failures[trackId] { return .failed(message) }
            return .notDownloaded
        }
    }

    func isDownloaded(trackId: String) -> Bool { return status(for: trackId) == .downloaded }

    func allDownloadedTracks() -> [Track] {
        return onMain {
            tracks.values.compactMap { track -> Track? in
                let url = audioURL(for: track.id)
                guard FileManager.default.fileExists(atPath: url.path) else { return nil }
                var playable = track
                playable.streamUrl = url.absoluteString
                return playable
            }.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        }
    }

    func download(track: Track) {
        onMain {
            guard !self.isDownloaded(trackId: track.id), self.generations[track.id] == nil else { return }
            let job = Job(track: track, generation: UUID())
            self.failures.removeValue(forKey: track.id)
            self.generations[track.id] = job.generation
            self.progress[track.id] = 0
            self.pending.append(job)
            self.pump()
            self.notifyStatus(track.id)
        }
    }

    func downloadPlaylist(tracks: [Track]) {
        for track in tracks { download(track: track) }
    }

    private func pump() {
        while running.count < 2 && !pending.isEmpty {
            let job = pending.removeFirst()
            guard generations[job.track.id] == job.generation else { continue }
            running[job.track.id] = job.generation
            StreamResolver.shared.resolveDownloadURL(for: job.track) { [weak self] result in
                DispatchQueue.main.async {
                    guard let self = self, self.generations[job.track.id] == job.generation else { return }
                    switch result {
                    case .success(let url):
                        guard url.scheme?.lowercased() == "https" else {
                            self.fail(job, message: "The download source is not a secure remote audio URL.")
                            return
                        }
                        var request = URLRequest(url: url)
                        request.allowsCellularAccess = !SettingsManager.shared.downloadWifiOnly
                        request.setValue("audio/mp4, audio/aac, audio/mpeg", forHTTPHeaderField: "Accept")
                        let task = self.downloadSession.downloadTask(with: request)
                        self.tasks[job.track.id] = task
                        self.taskJobs[task.taskIdentifier] = job
                        task.resume()
                    case .failure(let error):
                        self.fail(job, message: error.localizedDescription)
                    }
                }
            }
        }
    }

    func cancelDownload(trackId: String) {
        onMain {
            generations.removeValue(forKey: trackId)
            pending.removeAll { $0.track.id == trackId }
            running.removeValue(forKey: trackId)
            if let task = tasks.removeValue(forKey: trackId) {
                taskJobs.removeValue(forKey: task.taskIdentifier)
                task.cancel()
            }
            progress.removeValue(forKey: trackId)
            failures.removeValue(forKey: trackId)
            pump()
            notifyStatus(trackId)
        }
    }

    func deleteDownload(trackId: String) {
        onMain {
            cancelDownload(trackId: trackId)
            let file = audioURL(for: trackId)
            do {
                if FileManager.default.fileExists(atPath: file.path) { try FileManager.default.removeItem(at: file) }
                tracks.removeValue(forKey: trackId)
                fileNames.removeValue(forKey: trackId)
                try persistManifest()
                try? FileManager.default.removeItem(at: localArtworkURL(for: trackId))
                NotificationCenter.default.post(name: Self.listDidChangeNotification, object: nil)
            } catch { failures[trackId] = error.localizedDescription }
            notifyStatus(trackId)
        }
    }

    private func finish(_ job: Job) {
        generations.removeValue(forKey: job.track.id)
        running.removeValue(forKey: job.track.id)
        progress.removeValue(forKey: job.track.id)
        if let task = tasks.removeValue(forKey: job.track.id) { taskJobs.removeValue(forKey: task.taskIdentifier) }
        pump()
    }

    private func fail(_ job: Job, message: String) {
        guard generations[job.track.id] == job.generation else { return }
        failures[job.track.id] = message
        finish(job)
        notifyStatus(job.track.id)
    }

    private func notifyStatus(_ id: String) {
        NotificationCenter.default.post(name: Self.statusDidChangeNotification, object: nil,
                                        userInfo: ["trackId": id, "error": failures[id] ?? ""])
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64,
                    totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard let job = taskJobs[downloadTask.taskIdentifier], generations[job.track.id] == job.generation else { return }
        progress[job.track.id] = totalBytesExpectedToWrite > 0
            ? min(0.99, Float(totalBytesWritten) / Float(totalBytesExpectedToWrite)) : 0
        notifyStatus(job.track.id)
    }

    private func validatedExtension(task: URLSessionDownloadTask, location: URL) throws -> String {
        func invalid(_ message: String) -> NSError {
            return NSError(domain: "iMusic.Download", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
        }
        guard let response = task.response as? HTTPURLResponse, (200...299).contains(response.statusCode) else {
            throw invalid("The server refused the audio download. Please retry.")
        }
        let mime = response.mimeType?.lowercased() ?? ""
        let extensions = ["audio/mp4": "m4a", "audio/aac": "aac", "audio/mpeg": "mp3"]
        guard let fileExtension = extensions[mime] else { throw invalid("The server did not return an AAC or MP3 audio file.") }
        let attributes = try FileManager.default.attributesOfItem(atPath: location.path)
        let size = (attributes[.size] as? NSNumber)?.int64Value ?? 0
        guard size > 0 else { throw invalid("The audio download is empty.") }
        if response.expectedContentLength > 0 && size != response.expectedContentLength {
            throw invalid("The audio download is incomplete. Please retry.")
        }
        if response.statusCode == 206 {
            guard let range = response.value(forHTTPHeaderField: "Content-Range"),
                  range.hasPrefix("bytes 0-"), let totalString = range.split(separator: "/").last,
                  let total = Int64(totalString), total == size else {
                throw invalid("The server returned only part of the song. Please retry.")
            }
        }
        let handle = try FileHandle(forReadingFrom: location)
        let header = [UInt8](handle.readData(ofLength: 16))
        handle.closeFile()
        let isMP4 = header.count >= 8 && Array(header[4..<8]) == [102, 116, 121, 112]
        let isID3 = header.count >= 3 && Array(header[0..<3]) == [73, 68, 51]
        let isFrame = header.count >= 2 && header[0] == 255 && (header[1] & 224) == 224
        guard (fileExtension == "m4a" && isMP4) ||
                (fileExtension != "m4a" && (isID3 || isFrame)) else {
            throw invalid("The downloaded file is not valid AAC or MP3 media.")
        }
        return fileExtension
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let job = taskJobs[downloadTask.taskIdentifier], generations[job.track.id] == job.generation else { return }
        var destination: URL?
        let oldTrack = tracks[job.track.id]
        let oldName = fileNames[job.track.id]
        do {
            let fileExtension = try validatedExtension(task: downloadTask, location: location)
            let name = safeStem(job.track.id) + "-" + job.generation.uuidString + "." + fileExtension
            let target = downloadsDirectory.appendingPathComponent(name)
            destination = target
            try FileManager.default.moveItem(at: location, to: target)
            var saved = job.track
            saved.streamUrl = nil
            tracks[saved.id] = saved
            fileNames[saved.id] = name
            try persistManifest()
            failures.removeValue(forKey: saved.id)
            finish(job)
            NotificationCenter.default.post(name: Self.listDidChangeNotification, object: nil)
            notifyStatus(saved.id)
        } catch {
            tracks[job.track.id] = oldTrack
            fileNames[job.track.id] = oldName
            if let destination = destination { try? FileManager.default.removeItem(at: destination) }
            fail(job, message: error.localizedDescription)
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let job = taskJobs[task.taskIdentifier], generations[job.track.id] == job.generation else { return }
        fail(job, message: error?.localizedDescription ?? "The audio download did not produce a complete file.")
    }
}
