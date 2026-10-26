import Foundation

final class StreamResolver {
    static let shared = StreamResolver()

    private struct CachedStream {
        let url: URL
        let expires: Date
    }

    private let state = DispatchQueue(label: "iMusic.resolver")
    private var cache: [String: CachedStream] = [:]
    private var pending: [String: [(Result<URL, Error>) -> Void]] = [:]
    private let session: URLSession
    private let base = URL(string: "https://yt.chocolatemoo53.com")!

    private init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 5
        configuration.timeoutIntervalForResource = 8
        configuration.httpMaximumConnectionsPerHost = 3
        session = URLSession(configuration: configuration)
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
        resolve(track: track, itag: 140, completion: completion)
    }

    func resolveDownloadURL(for track: Track, completion: @escaping (Result<URL, Error>) -> Void) {
        resolve(track: track, itag: SettingsManager.shared.downloadQuality.itag, completion: completion)
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
                    if let value = selected?["url"] as? String, let url = URL(string: value),
                       url.scheme == "https", url.host == self.base.host {
                        result = .success(url)
                    } else {
                        result = .failure(self.failure("The streaming service did not provide a compatible proxied AAC stream."))
                    }
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

    private func failure(_ message: String) -> NSError {
        return NSError(domain: "iMusic.StreamResolver", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }
}
