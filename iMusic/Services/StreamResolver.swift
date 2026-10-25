import Foundation

final class StreamResolver {

    static let shared = StreamResolver()

    private let session: URLSession

    // Invidious fallback instances
    private let invidiousInstances = [
        "https://yt.chocolatemoo53.com",
        "https://inv.nadeko.net",
        "https://invidious.nerdvpn.de"
    ]

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 20
        self.session = URLSession(configuration: config)
    }

    func resolveStreamURL(for videoId: String, completion: @escaping (Result<URL, Error>) -> Void) {
        // Tier 1: Innertube ANDROID_VR client
        resolveViaInnertube(videoId: videoId, clientName: "ANDROID_VR", clientVersion: "1.65.10", clientId: "28") { [weak self] result in
            switch result {
            case .success(let url):
                completion(.success(url))
            case .failure:
                // Tier 2: Innertube TVHTML5 Embedded client
                self?.resolveViaEmbeddedInnertube(videoId: videoId) { embeddedResult in
                    switch embeddedResult {
                    case .success(let url):
                        completion(.success(url))
                    case .failure:
                        // Tier 3: Invidious API instance fallback
                        self?.resolveViaInvidious(videoId: videoId, instanceIndex: 0, completion: completion)
                    }
                }
            }
        }
    }

    // MARK: - Tier 1: Innertube Android VR / iOS

    private func resolveViaInnertube(videoId: String, clientName: String, clientVersion: String, clientId: String, completion: @escaping (Result<URL, Error>) -> Void) {
        guard let url = URL(string: "https://www.youtube.com/youtubei/v1/player?prettyPrint=false") else {
            completion(.failure(NSError(domain: "StreamResolver", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("com.google.android.apps.youtube.vr.oculus/1.65.10 (Linux; U; Android 12L; eureka-user Build/SQ3A.220605.009.A1) gzip", forHTTPHeaderField: "User-Agent")
        request.setValue(clientId, forHTTPHeaderField: "X-YouTube-Client-Name")
        request.setValue(clientVersion, forHTTPHeaderField: "X-YouTube-Client-Version")
        request.setValue("https://www.youtube.com", forHTTPHeaderField: "Origin")

        let payload: [String: Any] = [
            "context": [
                "client": [
                    "clientName": clientName,
                    "clientVersion": clientVersion,
                    "deviceMake": "Oculus",
                    "deviceModel": "Quest 3",
                    "osName": "Android",
                    "osVersion": "12L",
                    "gl": "US",
                    "hl": "en"
                ]
            ],
            "videoId": videoId,
            "contentCheckOk": true,
            "racyCheckOk": true
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload, options: [])
        } catch {
            completion(.failure(error))
            return
        }

        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data,
                  let json = (try? JSONSerialization.jsonObject(with: data, options: [])) as? [String: Any] else {
                completion(.failure(NSError(domain: "StreamResolver", code: -2, userInfo: [NSLocalizedDescriptionKey: "Malformed Innertube response"])))
                return
            }

            if let streamURL = self.extractAudioStreamURL(from: json) {
                completion(.success(streamURL))
            } else {
                completion(.failure(NSError(domain: "StreamResolver", code: -3, userInfo: [NSLocalizedDescriptionKey: "No playable stream URL in Innertube data"])))
            }
        }
        task.resume()
    }

    // MARK: - Tier 2: TVHTML5 Embedded

    private func resolveViaEmbeddedInnertube(videoId: String, completion: @escaping (Result<URL, Error>) -> Void) {
        guard let url = URL(string: "https://www.youtube.com/youtubei/v1/player?prettyPrint=false") else {
            completion(.failure(NSError(domain: "StreamResolver", code: -1, userInfo: nil)))
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
            completion(.failure(NSError(domain: "StreamResolver", code: -1, userInfo: nil)))
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
                  let streamURL = self.extractAudioStreamURL(from: json) else {
                completion(.failure(NSError(domain: "StreamResolver", code: -2, userInfo: nil)))
                return
            }
            completion(.success(streamURL))
        }
        task.resume()
    }

    // MARK: - Tier 3: Invidious Instances

    private func resolveViaInvidious(videoId: String, instanceIndex: Int, completion: @escaping (Result<URL, Error>) -> Void) {
        guard instanceIndex < invidiousInstances.count else {
            completion(.failure(NSError(domain: "StreamResolver", code: -4, userInfo: [NSLocalizedDescriptionKey: "All fallback stream resolvers exhausted"])))
            return
        }

        let base = invidiousInstances[instanceIndex]
        guard let url = URL(string: "\(base)/api/v1/videos/\(videoId)") else {
            self.resolveViaInvidious(videoId: videoId, instanceIndex: instanceIndex + 1, completion: completion)
            return
        }

        let task = session.dataTask(with: url) { [weak self] data, _, error in
            if error != nil || data == nil {
                self?.resolveViaInvidious(videoId: videoId, instanceIndex: instanceIndex + 1, completion: completion)
                return
            }

            guard let data = data,
                  let json = (try? JSONSerialization.jsonObject(with: data, options: [])) as? [String: Any] else {
                self?.resolveViaInvidious(videoId: videoId, instanceIndex: instanceIndex + 1, completion: completion)
                return
            }

            // Look for audio formats in adaptiveFormats
            if let adaptive = json["adaptiveFormats"] as? [[String: Any]] {
                // Prefer m4a AAC (itag 140 is 128k AAC, hardware decoded on Apple A8)
                let audioFormats = adaptive.filter { fmt in
                    guard let type = fmt["type"] as? String else { return false }
                    return type.hasPrefix("audio/")
                }

                let preferred = audioFormats.first { fmt in
                    let container = (fmt["container"] as? String) ?? ""
                    let encoding = (fmt["encoding"] as? String) ?? ""
                    return container == "m4a" || encoding == "aac"
                } ?? audioFormats.first

                if let streamUrlStr = preferred?["url"] as? String,
                   let streamUrl = URL(string: streamUrlStr) {
                    completion(.success(streamUrl))
                    return
                }
            }

            // Try next instance
            self?.resolveViaInvidious(videoId: videoId, instanceIndex: instanceIndex + 1, completion: completion)
        }
        task.resume()
    }

    // MARK: - Extraction Helpers

    private func extractAudioStreamURL(from json: [String: Any]) -> URL? {
        guard let streamingData = json["streamingData"] as? [String: Any] else {
            return nil
        }

        // Check for HLS manifest URL first
        if let hlsStr = streamingData["hlsManifestUrl"] as? String,
           let hlsURL = URL(string: hlsStr) {
            return hlsURL
        }

        // Check adaptiveFormats for audio/mp4 (AAC)
        if let adaptive = streamingData["adaptiveFormats"] as? [[String: Any]] {
            let audioFormats = adaptive.filter { fmt in
                guard let mime = fmt["mimeType"] as? String else { return false }
                return mime.hasPrefix("audio/")
            }

            // Prioritize itag 140 (128k AAC) or audio/mp4
            let preferred = audioFormats.first { fmt in
                let itag = fmt["itag"] as? Int ?? 0
                let mime = (fmt["mimeType"] as? String) ?? ""
                return itag == 140 || mime.contains("audio/mp4")
            } ?? audioFormats.first

            if let urlStr = preferred?["url"] as? String,
               let streamURL = URL(string: urlStr) {
                return streamURL
            }
        }

        return nil
    }
}
