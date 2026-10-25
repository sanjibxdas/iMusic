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

        var components = URLComponents(string: "https://lrclib.net/api/get")
        var queryItems = [
            URLQueryItem(name: "track_name", value: track.title),
            URLQueryItem(name: "artist_name", value: track.artist)
        ]
        if track.duration > 0 {
            queryItems.append(URLQueryItem(name: "duration", value: "\(Int(track.duration))"))
        }
        if !track.album.isEmpty {
            queryItems.append(URLQueryItem(name: "album_name", value: track.album))
        }
        components?.queryItems = queryItems

        guard let url = components?.url else {
            completion(nil)
            return
        }

        let task = session.dataTask(with: url) { [weak self] data, response, _ in
            guard let data = data,
                  let http = response as? HTTPURLResponse, http.statusCode == 200,
                  let json = (try? JSONSerialization.jsonObject(with: data, options: [])) as? [String: Any] else {
                DispatchQueue.main.async { completion(nil) }
                return
            }

            var lines: [LyricLine] = []
            if let synced = json["syncedLyrics"] as? String, !synced.isEmpty {
                lines = LyricsDocument.parseLRC(synced)
            }
            let plain = json["plainLyrics"] as? String

            let doc = LyricsDocument(lines: lines, plainLyrics: plain)
            self?.cache[track.id] = doc

            DispatchQueue.main.async {
                completion(doc)
            }
        }
        task.resume()
    }
}
