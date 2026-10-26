import Foundation

final class StreamResolver {
    static let shared = StreamResolver()

    private struct CachedStream {
        let url: URL
        let expires: Date
    }

    private let state = DispatchQueue(label: "iMusic.resolver")
    private let probeQueue = DispatchQueue(label: "iMusic.resolver.probe", qos: .userInitiated)
    private var cache: [String: CachedStream] = [:]
    private var pending: [String: [(Result<URL, Error>) -> Void]] = [:]
    private let session: URLSession
    private let probeSession: URLSession
    private let base = URL(string: "https://yt.chocolatemoo53.com")!

    private init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 5
        configuration.timeoutIntervalForResource = 8
        configuration.httpMaximumConnectionsPerHost = 3
        session = URLSession(configuration: configuration)

        let probeConfiguration = URLSessionConfiguration.ephemeral
        probeConfiguration.timeoutIntervalForRequest = 6
        probeConfiguration.timeoutIntervalForResource = 10
        probeSession = URLSession(configuration: probeConfiguration)
    }

    func invalidate(trackId: String) {
        state.async { self.cache.removeAll() }
    }

    func resolveStreamURL(for track: Track, completion: @escaping (Result<URL, Error>) -> Void) {
        let local = DownloadManager.shared.localAudioURL(for: track.id)
        if FileManager.default.fileExists(atPath: local.path) {
            DispatchQueue.main.async { completion(.success(local)) }
            return
        }
        if let value = track.streamUrl, let url = URL(string: value), url.isFileURL,
           FileManager.default.fileExists(atPath: url.path) {
            DispatchQueue.main.async { completion(.success(url)) }
            return
        }
        // A previously cached track replays from disk, so switching back is instant.
        if SettingsManager.shared.audioCacheEnabled, let cached = AudioCache.shared.cachedURL(for: track.id) {
            DispatchQueue.main.async { completion(.success(cached)) }
            return
        }
        resolve(track: track, itag: 140) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let remote):
                guard SettingsManager.shared.audioCacheEnabled else {
                    DispatchQueue.main.async { completion(.success(remote)) }
                    return
                }
                if SettingsManager.shared.progressiveBuffering {
                    // Hand the remote URL over immediately and cache in the background.
                    DispatchQueue.main.async { completion(.success(remote)) }
                    AudioCache.shared.cache(trackId: track.id, remoteURL: remote) { _ in
                        self.trimCacheIfNeeded()
                    }
                } else {
                    // Wait for the whole file so playback never touches the network.
                    AudioCache.shared.cache(trackId: track.id, remoteURL: remote) { cached in
                        self.trimCacheIfNeeded()
                        DispatchQueue.main.async { completion(cached) }
                    }
                }
            case .failure(let error):
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
    }

    private func trimCacheIfNeeded() {
        let limitMB = SettingsManager.shared.audioCacheLimitMB
        guard limitMB > 0 else { return }
        AudioCache.shared.trim(keepingBytes: Int64(limitMB) * 1024 * 1024)
    }

    func resolveDownloadURL(for track: Track, completion: @escaping (Result<URL, Error>) -> Void) {
        resolve(track: track, itag: SettingsManager.shared.downloadQuality.itag, completion: completion)
    }

    /// Resolves the next track during the current one, so its round trip is not felt at switch time.
    /// Also fills the audio cache for it when caching is on, making the switch instant.
    func prefetch(_ track: Track?) {
        guard let track = track, !track.id.hasPrefix("itunes_") else { return }
        let local = DownloadManager.shared.localAudioURL(for: track.id)
        if FileManager.default.fileExists(atPath: local.path) { return }
        if SettingsManager.shared.audioCacheEnabled, AudioCache.shared.isCached(trackId: track.id) { return }
        resolveStreamURL(for: track) { _ in }
    }

    func resolveDirectYouTubeId(_ videoId: String, completion: @escaping (Result<URL, Error>) -> Void) {
        resolve(track: Track(id: videoId, title: "", artist: ""), itag: 140, completion: completion)
    }

    private func resolve(track: Track, itag: Int, completion: @escaping (Result<URL, Error>) -> Void) {
        if track.id.hasPrefix("itunes_") {
            DispatchQueue.main.async {
                completion(.failure(self.failure("This result has no verified YouTube track. Search by song and artist instead.")))
            }
            return
        }
        guard track.id.range(of: "^[A-Za-z0-9_-]{11}$", options: .regularExpression) != nil else {
            DispatchQueue.main.async { completion(.failure(self.failure("This item is not a playable song."))) }
            return
        }
        let key = "\(track.id):\(itag)"
        state.async {
            if let entry = self.cache[key], entry.expires.timeIntervalSinceNow > 60 {
                DispatchQueue.main.async { completion(.success(entry.url)) }
                return
            }
            if self.pending[key] != nil {
                self.pending[key]?.append(completion)
                return
            }
            self.pending[key] = [completion]
            var components = URLComponents(url: self.base.appendingPathComponent("api/v1/videos/\(track.id)"), resolvingAgainstBaseURL: false)!
            components.queryItems = [URLQueryItem(name: "local", value: "true")]
            var request = URLRequest(url: components.url!)
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            let started = Date()
            self.session.dataTask(with: request) { data, response, error in
                let result: Result<URL, Error>
                if let error = error {
                    result = .failure(error)
                } else if let http = response as? HTTPURLResponse, http.statusCode == 200,
                          let data = data,
                          let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
                          let formats = json["adaptiveFormats"] as? [[String: Any]] {
                    let aac = formats.filter { format in
                        let mime = (format["type"] as? String ?? "").lowercased()
                        return mime.hasPrefix("audio/mp4") && (format["url"] as? String) != nil
                    }
                    let selected = aac.first { String(describing: $0["itag"] ?? "") == String(itag) } ?? aac.first
                    guard let value = selected?["url"] as? String, let url = URL(string: value),
                          url.scheme == "https", url.host == self.base.host else {
                        print("Stream metadata: \(Int(Date().timeIntervalSince(started) * 1000)) ms")
                        self.finish(key: key, result: .failure(self.failure("The streaming service did not provide a compatible proxied AAC stream.")))
                        return
                    }
                    // Confirm the proxy really serves audio before handing the URL to AVPlayer;
                    // an expired token otherwise only fails after playback has been requested.
                    self.probe(url) { ok in
                        print("Stream metadata: \(Int(Date().timeIntervalSince(started) * 1000)) ms, probe: \(ok ? "ok" : "failed")")
                        let result: Result<URL, Error> = ok
                            ? .success(url)
                            : .failure(self.failure("The audio link could not be reached. Please retry."))
                        self.finish(key: key, result: result)
                    }
                    return
                } else {
                    result = .failure(self.failure("The streaming service is unavailable. Please retry."))
                }
                print("Stream metadata: \(Int(Date().timeIntervalSince(started) * 1000)) ms")
                self.finish(key: key, result: result)
            }.resume()
        }
    }

    private func finish(key: String, result: Result<URL, Error>) {
        state.async {
            if case .success(let url) = result {
                let expiry = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?
                    .first(where: { $0.name == "expire" })?.value.flatMap(Double.init)
                let deadline = min(expiry ?? Date().addingTimeInterval(900).timeIntervalSince1970, Date().addingTimeInterval(900).timeIntervalSince1970)
                if self.cache.count >= 40 { self.cache.removeAll() }
                self.cache[key] = CachedStream(url: url, expires: Date(timeIntervalSince1970: deadline))
            }
            let callbacks = self.pending.removeValue(forKey: key) ?? []
            DispatchQueue.main.async { callbacks.forEach { $0(result) } }
        }
    }

    /// Range-requests the first audio bytes so a dead or expired link is caught before playback.
    private func probe(_ url: URL, completion: @escaping (Bool) -> Void) {
        var request = URLRequest(url: url)
        request.setValue("bytes=0-2047", forHTTPHeaderField: "Range")
        probeSession.dataTask(with: request) { data, response, error in
            let http = response as? HTTPURLResponse
            let statusOK = http.map { $0.statusCode == 200 || $0.statusCode == 206 } ?? false
            let mime = (http?.allHeaderFields["Content-Type"] as? String)?.lowercased() ?? ""
            let isAudio = mime.hasPrefix("audio/") || mime.contains("mp4")
            completion(error == nil && statusOK && isAudio && (data?.count ?? 0) > 0)
        }.resume()
    }

    private func failure(_ message: String) -> NSError {
        return NSError(domain: "iMusic.StreamResolver", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }
}
