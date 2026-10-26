import Foundation

final class LyricsService {

    static let shared = LyricsService()

    private let session: URLSession
    private var cache: [String: LyricsDocument] = [:]

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 8
        self.session = URLSession(configuration: config)
    }

    func fetchLyrics(for track: Track, completion: @escaping (LyricsDocument?) -> Void) {
        if let cached = cache[track.id] {
            completion(cached)
            return
        }

        let cleanedTitle = cleanTitle(track.title)
        let cleanedArtist = cleanArtist(track.artist)

        // Strategy 1: LRCLIB /api/get with clean title and artist
        fetchLrclibGet(title: cleanedTitle, artist: cleanedArtist) { [weak self] doc in
            if let doc = doc, doc.hasTiming || doc.plainLyrics != nil {
                self?.cache[track.id] = doc
                DispatchQueue.main.async { completion(doc) }
                return
            }

            // Strategy 2: LRCLIB /api/search with fuzzy query
            self?.fetchLrclibSearch(title: cleanedTitle, artist: cleanedArtist) { searchDoc in
                if let searchDoc = searchDoc, searchDoc.hasTiming || searchDoc.plainLyrics != nil {
                    self?.cache[track.id] = searchDoc
                    DispatchQueue.main.async { completion(searchDoc) }
                    return
                }

                // Strategy 3: YouTube transcript fallback
                self?.fetchYouTubeTranscript(videoId: track.id) { ytDoc in
                    if let ytDoc = ytDoc {
                        self?.cache[track.id] = ytDoc
                        DispatchQueue.main.async { completion(ytDoc) }
                    } else {
                        DispatchQueue.main.async { completion(nil) }
                    }
                }
            }
        }
    }

    // MARK: - Cleaning Helpers

    private func cleanTitle(_ title: String) -> String {
        var result = title
        // Remove common YouTube suffixes
        let patterns = [
            "\\(Official Video\\)",
            "\\(Official Music Video\\)",
            "\\(Official Audio\\)",
            "\\[Official Video\\]",
            "\\[Official Audio\\]",
            "\\[Music Video\\]",
            "\\(Lyrics\\)",
            "\\[Lyrics\\]",
            "\\(Visualizer\\)",
            "\\[Visualizer\\]",
            "\\(Audio\\)",
            "\\[Audio\\]",
            "\\(feat\\..*?\\)",
            "\\(ft\\..*?\\)",
            "\\(with.*?\\)"
        ]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                result = regex.stringByReplacingMatches(in: result, options: [], range: NSRange(location: 0, length: result.count), withTemplate: "")
            }
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func cleanArtist(_ artist: String) -> String {
        let parts = artist.components(separatedBy: " • ")
        return (parts.first ?? artist).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - LRCLIB Endpoints

    private func fetchLrclibGet(title: String, artist: String, completion: @escaping (LyricsDocument?) -> Void) {
        var components = URLComponents(string: "https://lrclib.net/api/get")
        components?.queryItems = [
            URLQueryItem(name: "track_name", value: title),
            URLQueryItem(name: "artist_name", value: artist)
        ]

        guard let url = components?.url else {
            completion(nil)
            return
        }

        let task = session.dataTask(with: url) { data, response, _ in
            guard let data = data,
                  let http = response as? HTTPURLResponse, http.statusCode == 200,
                  let json = (try? JSONSerialization.jsonObject(with: data, options: [])) as? [String: Any] else {
                completion(nil)
                return
            }

            var lines: [LyricLine] = []
            if let synced = json["syncedLyrics"] as? String, !synced.isEmpty {
                lines = LyricsDocument.parseLRC(synced)
            }
            let plain = json["plainLyrics"] as? String
            completion(LyricsDocument(lines: lines, plainLyrics: plain))
        }
        task.resume()
    }

    private func fetchLrclibSearch(title: String, artist: String, completion: @escaping (LyricsDocument?) -> Void) {
        let query = "\(title) \(artist)"
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://lrclib.net/api/search?q=\(encoded)") else {
            completion(nil)
            return
        }

        let task = session.dataTask(with: url) { data, response, _ in
            guard let data = data,
                  let http = response as? HTTPURLResponse, http.statusCode == 200,
                  let list = (try? JSONSerialization.jsonObject(with: data, options: [])) as? [[String: Any]],
                  let first = list.first else {
                completion(nil)
                return
            }

            var lines: [LyricLine] = []
            if let synced = first["syncedLyrics"] as? String, !synced.isEmpty {
                lines = LyricsDocument.parseLRC(synced)
            }
            let plain = first["plainLyrics"] as? String
            completion(LyricsDocument(lines: lines, plainLyrics: plain))
        }
        task.resume()
    }

    // MARK: - YouTube Transcript Fallback

    private func fetchYouTubeTranscript(videoId: String, completion: @escaping (LyricsDocument?) -> Void) {
        guard let url = URL(string: "https://www.youtube.com/youtubei/v1/get_transcript") else {
            completion(nil)
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")

        let payload: [String: Any] = [
            "context": [
                "client": [
                    "clientName": "WEB",
                    "clientVersion": "2.20231215.01.00",
                    "gl": "US",
                    "hl": "en"
                ]
            ],
            "params": "\n\u{0b}\(videoId)"
        ]

        guard let bodyData = try? JSONSerialization.data(withJSONObject: payload, options: []) else {
            completion(nil)
            return
        }
        request.httpBody = bodyData

        let task = session.dataTask(with: request) { data, _, _ in
            guard let data = data,
                  let json = (try? JSONSerialization.jsonObject(with: data, options: [])) as? [String: Any] else {
                completion(nil)
                return
            }

            // Extract cues from transcript renderer
            var lines: [LyricLine] = []
            if let actions = json["actions"] as? [[String: Any]] {
                for act in actions {
                    if let update = act["updateEngagementPanelAction"] as? [String: Any],
                       let content = update["content"] as? [String: Any],
                       let trans = content["transcriptRenderer"] as? [String: Any],
                       let body = trans["body"] as? [String: Any],
                       let cueGroup = (body["transcriptBodyRenderer"] as? [String: Any])?["cueGroups"] as? [[String: Any]] {
                        for cg in cueGroup {
                            if let cueRenderer = (cg["transcriptCueGroupRenderer"] as? [String: Any])?["cues"] as? [[String: Any]] {
                                for cue in cueRenderer {
                                    if let cr = cue["transcriptCueRenderer"] as? [String: Any],
                                       let startMsStr = cr["startOffsetMs"] as? String,
                                       let startMs = Double(startMsStr),
                                       let runs = (cr["cue"] as? [String: Any])?["runs"] as? [[String: Any]],
                                       let text = runs.first?["text"] as? String {
                                        lines.append(LyricLine(time: startMs / 1000.0, text: text))
                                    }
                                }
                            }
                        }
                    }
                }
            }

            if !lines.isEmpty {
                completion(LyricsDocument(lines: lines, plainLyrics: nil))
            } else {
                completion(nil)
            }
        }
        task.resume()
    }
}
