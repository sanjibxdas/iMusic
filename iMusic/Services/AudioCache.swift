import Foundation
import UIKit

/// Stores resolved audio on disk the first time a track is streamed, so replaying a
/// track in the same session (or later) never waits on the proxy again.
final class AudioCache {
    static let shared = AudioCache()
    static let didChangeNotification = Notification.Name("AudioCacheDidChange")

    private struct Completion {
        let handlers: [(Result<URL, Error>) -> Void]
    }

    private let state = DispatchQueue(label: "iMusic.audiocache")
    private let directory: URL
    private let session: URLSession
    private var inflight: [String: Completion] = [:]

    private init() {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        directory = base.appendingPathComponent("AudioCache", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)

        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 300
        configuration.httpMaximumConnectionsPerHost = 3
        session = URLSession(configuration: configuration)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }

    // MARK: - Lookup

    func cachedURL(for trackId: String) -> URL? {
        let url = fileURL(for: trackId)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    func isCached(trackId: String) -> Bool {
        return cachedURL(for: trackId) != nil
    }

    private func fileURL(for trackId: String) -> URL {
        return directory.appendingPathComponent(safeName(trackId) + ".m4a")
    }

    private func safeName(_ id: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        return String(id.unicodeScalars.map { allowed.contains($0) ? Character($0) : "_" })
    }

    // MARK: - Populate

    /// Downloads the track into the cache and calls back with a local file URL.
    /// Concurrent requests for the same track share one download.
    func cache(trackId: String, remoteURL: URL, completion: @escaping (Result<URL, Error>) -> Void) {
        if let local = cachedURL(for: trackId) {
            DispatchQueue.main.async { completion(.success(local)) }
            return
        }
        state.async {
            if var existing = self.inflight[trackId] {
                existing.handlers.append(completion)
                self.inflight[trackId] = existing
                return
            }
            self.inflight[trackId] = Completion(handlers: [completion])
            var request = URLRequest(url: remoteURL)
            request.allowsCellularAccess = !SettingsManager.shared.downloadWifiOnly || SettingsManager.shared.streamOnCellular
            self.session.downloadTask(with: request) { location, response, error in
                let result = self.commit(trackId: trackId, location: location, response: response, error: error)
                self.state.async {
                    let handlers = self.inflight.removeValue(forKey: trackId)?.handlers ?? []
                    DispatchQueue.main.async {
                        handlers.forEach { $0(result) }
                        if case .success = result {
                            NotificationCenter.default.post(name: AudioCache.didChangeNotification, object: nil)
                        }
                    }
                }
            }.resume()
        }
    }

    private func commit(trackId: String, location: URL?, response: URLResponse?, error: Error?) -> Result<URL, Error> {
        func failure(_ message: String) -> Result<URL, Error> {
            return .failure(NSError(domain: "iMusic.AudioCache", code: 1, userInfo: [NSLocalizedDescriptionKey: message]))
        }
        if error != nil { return failure("Caching was interrupted.") }
        guard let location = location else { return failure("Caching produced no file.") }
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            return failure("The audio source refused the download.")
        }
        let mime = (http.allHeaderFields["Content-Type"] as? String)?.lowercased() ?? ""
        guard mime.hasPrefix("audio/") || mime.contains("mp4") else {
            return failure("The audio source returned a non-audio response.")
        }
        let attributes = try? FileManager.default.attributesOfItem(atPath: location.path)
        let size = (attributes?[.size] as? NSNumber)?.int64Value ?? 0
        // A truncated cache file would poison every later play, so require a real body.
        guard size > 512 else { return failure("The cached audio was empty.") }

        let destination = fileURL(for: trackId)
        do {
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.moveItem(at: location, to: destination)
            return .success(destination)
        } catch {
            return failure("Caching could not be saved.")
        }
    }

    // MARK: - Maintenance

    func cachedSizeInBytes() -> Int64 {
        let keys: [URLResourceKey] = [.fileSizeKey]
        guard let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: keys) else {
            return 0
        }
        return files.reduce(into: Int64(0)) { total, url in
            let size = (try? url.resourceValues(forKeys: Set(keys)).fileSize) ?? 0
            total += Int64(size ?? 0)
        }
    }

    func clear() {
        state.async {
            let files = (try? FileManager.default.contentsOfDirectory(at: self.directory, includingPropertiesForKeys: nil)) ?? []
            for file in files { try? FileManager.default.removeItem(at: file) }
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: AudioCache.didChangeNotification, object: nil)
            }
        }
    }

    /// Trims the oldest entries once the cache exceeds the requested budget.
    func trim(keepingBytes limit: Int64) {
        state.async {
            let keys: Set<URLResourceKey> = [.fileSizeKey, .contentModificationDateKey]
            guard let files = try? FileManager.default.contentsOfDirectory(at: self.directory, includingPropertiesForKeys: Array(keys)) else { return }
            var entries: [(url: URL, size: Int64, date: Date)] = files.compactMap { url in
                guard let values = try? url.resourceValues(forKeys: keys) else { return nil }
                return (url, Int64(values.fileSize ?? 0), values.contentModificationDate ?? .distantPast)
            }
            var total = entries.reduce(into: Int64(0)) { $0 += $1.size }
            guard total > limit else { return }
            entries.sort { $0.date < $1.date }
            for entry in entries where total > limit {
                try? FileManager.default.removeItem(at: entry.url)
                total -= entry.size
            }
        }
    }

    @objc private func handleMemoryWarning() {
        // Files stay on disk; only in-flight bookkeeping is kept small.
        state.async { if self.inflight.count > 4 { self.inflight = [:] } }
    }
}
