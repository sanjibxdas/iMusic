import Foundation

final class StreamResolver {

    static let shared = StreamResolver()

    private let session: URLSession
    private var resolvedUrlCache: [String: URL] = [:]

    // Invidious instances with local proxy enabled (?local=true)
    private let invidiousInstances = [
        "https://yt.chocolatemoo53.com",
        "https://invidious.nerdvpn.de",
        "https://inv.nadeko.net"
    ]

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 12
        config.timeoutIntervalForResource = 25
        self.session = URLSession(configuration: config)
    }

    func resolveStreamURL(for track: Track, completion: @escaping (Result<URL, Error>) -> Void) {
        // 1. Check in-memory cache
        if let cached = resolvedUrlCache[track.id] {
            completion(.success(cached))
            return
        }

        // 2. Check if track has a direct streamUrl already
        if let direct = track.streamUrl, let url = URL(string: direct) {
            resolvedUrlCache[track.id] = url
            completion(.success(url))
            return
        }

        // 3. If ID is an iTunes placeholder ("itunes_..."), first search YouTube for the real video ID
        if track.id.hasPrefix("itunes_") {
            let query = "\(track.title) \(track.artist)"
            MusicAPIService.shared.search(query: query) { [weak self] searchResult in
                switch searchResult {
                case .success(let tracks) where !tracks.isEmpty:
                    if let realId = tracks.first(where: { !$0.id.hasPrefix("itunes_") })?.id {
                        self?.resolveDirectYouTubeId(realId, completion: completion)
                        return
                    }
                    fallthrough
                default:
                    completion(.failure(NSError(domain: "StreamResolver", code: -404, userInfo: [NSLocalizedDescriptionKey: "Could not find YouTube stream for song"])))
                }
            }
            return
        }

        // 4. Resolve directly using YouTube Video ID
        resolveDirectYouTubeId(track.id, completion: completion)
    }

    func resolveDirectYouTubeId(_ videoId: String, completion: @escaping (Result<URL, Error>) -> Void) {
        if let cached = resolvedUrlCache[videoId] {
            completion(.success(cached))
            return
        }

        resolveViaInvidious(videoId: videoId, instanceIndex: 0) { [weak self] result in
            switch result {
            case .success(let streamUrl):
                self?.resolvedUrlCache[videoId] = streamUrl
                completion(.success(streamUrl))
            case .failure:
                // Fallback: try raw Innertube player endpoint
                self?.resolveViaEmbeddedInnertube(videoId: videoId) { embeddedResult in
                    switch embeddedResult {
                    case .success(let streamUrl):
                        self?.resolvedUrlCache[videoId] = streamUrl
                        completion(.success(streamUrl))
                    case .failure(let err):
                        completion(.failure(err))
                    }
                }
            }
        }
    }

    // MARK: - Invidious API with Local Proxy (?local=true)

    private func resolveViaInvidious(videoId: String, instanceIndex: Int, completion: @escaping (Result<URL, Error>) -> Void) {
        guard instanceIndex < invidiousInstances.count else {
            completion(.failure(NSError(domain: "StreamResolver", code: -1, userInfo: [NSLocalizedDescriptionKey: "All streaming proxies failed"])))
            return
        }

        let base = invidiousInstances[instanceIndex]
        guard let url = URL(string: "\(base)/api/v1/videos/\(videoId)?local=true") else {
            resolveViaInvidious(videoId: videoId, instanceIndex: instanceIndex + 1, completion: completion)
            return
        }

        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 12_5_8 like Mac OS X)", forHTTPHeaderField: "User-Agent")

        let task = session.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }

            if error != nil || data == nil {
                self.resolveViaInvidious(videoId: videoId, instanceIndex: instanceIndex + 1, completion: completion)
                return
            }

            guard let data = data,
                  let json = (try? JSONSerialization.jsonObject(with: data, options: [])) as? [String: Any],
                  let adaptive = json["adaptiveFormats"] as? [[String: Any]] else {
                self.resolveViaInvidious(videoId: videoId, instanceIndex: instanceIndex + 1, completion: completion)
                return
            }

            // Filter audio formats
            let audioFormats = adaptive.filter { fmt in
                guard let type = fmt["type"] as? String else { return false }
                return type.hasPrefix("audio/")
            }

            // Prefer m4a / AAC (itag 140 or audio/mp4 container)
            let preferred = audioFormats.first { fmt in
                let container = (fmt["container"] as? String) ?? ""
                let encoding = (fmt["encoding"] as? String) ?? ""
                let itag = (fmt["itag"] as? Int) ?? 0
                return container == "m4a" || encoding == "aac" || itag == 140
            } ?? audioFormats.first

            if let streamUrlStr = preferred?["url"] as? String,
               let streamUrl = URL(string: streamUrlStr) {
                completion(.success(streamUrl))
            } else {
                self.resolveViaInvidious(videoId: videoId, instanceIndex: instanceIndex + 1, completion: completion)
            }
        }
        task.resume()
    }

    // MARK: - Embedded Innertube Fallback

    private func resolveViaEmbeddedInnertube(videoId: String, completion: @escaping (Result<URL, Error>) -> Void) {
        guard let url = URL(string: "https://www.youtube.com/youtubei/v1/player?prettyPrint=false") else {
            completion(.failure(NSError(domain: "StreamResolver", code: -2, userInfo: nil)))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")
        request.setValue("https://www.youtube.com", forHTTPHeaderField: "Origin")
        request.setValue("https://www.youtube.com/embed/\(videoId)", forHTTPHeaderField: "Referer")

        let payload: [String: Any] = [
            "context": [
                "client": [
                    "clientName": "WEB_EMBEDDED_PLAYER",
                    "clientVersion": "2.20240501.00.00",
                    "gl": "US",
                    "hl": "en"
                ],
                "thirdParty": [
                    "embedUrl": "https://www.youtube.com/embed/\(videoId)"
                ]
            ],
            "videoId": videoId
        ]

        guard let bodyData = try? JSONSerialization.data(withJSONObject: payload, options: []) else {
            completion(.failure(NSError(domain: "StreamResolver", code: -3, userInfo: nil)))
            return
        }
        request.httpBody = bodyData

        let task = session.dataTask(with: request) { data, _, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let data = data,
                  let json = (try? JSONSerialization.jsonObject(with: data, options: [])) as? [String: Any],
                  let streamingData = json["streamingData"] as? [String: Any] else {
                completion(.failure(NSError(domain: "StreamResolver", code: -4, userInfo: nil)))
                return
            }

            if let hlsStr = streamingData["hlsManifestUrl"] as? String,
               let hlsUrl = URL(string: hlsStr) {
                completion(.success(hlsUrl))
                return
            }

            if let adaptive = streamingData["adaptiveFormats"] as? [[String: Any]] {
                let audioFormats = adaptive.filter { fmt in
                    guard let mime = fmt["mimeType"] as? String else { return false }
                    return mime.hasPrefix("audio/")
                }
                if let urlStr = audioFormats.first?["url"] as? String,
                   let streamUrl = URL(string: urlStr) {
                    completion(.success(streamUrl))
                    return
                }
            }

            completion(.failure(NSError(domain: "StreamResolver", code: -5, userInfo: [NSLocalizedDescriptionKey: "No audio stream available"])))
        }
        task.resume()
    }
}
