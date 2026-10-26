import Foundation

enum SearchFilter: String, CaseIterable {
    case all = "All"
    case songs = "Songs"
    case albums = "Albums"
    case artists = "Artists"
    case playlists = "Playlists"
}

struct MusicSearchResults {
    var tracks: [Track] = []
    var albums: [Album] = []
}

final class MusicAPIService {
    static let shared = MusicAPIService()
    private let session: URLSession
    private let context: [String: Any] = ["client": ["clientName": "WEB_REMIX", "clientVersion": "1.20231215.01.00", "hl": "en", "gl": "US"]]

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 20
        session = URLSession(configuration: config)
    }

    private func request(_ endpoint: String, body: [String: Any], completion: @escaping (Result<[String: Any], Error>) -> Void) {
        var request = URLRequest(url: URL(string: "https://music.youtube.com/youtubei/v1/\(endpoint)")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("https://music.youtube.com", forHTTPHeaderField: "Origin")
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        var payload = body
        payload["context"] = context
        do { request.httpBody = try JSONSerialization.data(withJSONObject: payload) }
        catch { DispatchQueue.main.async { completion(.failure(error)) }; return }
        session.dataTask(with: request) { data, response, error in
            let result: Result<[String: Any], Error>
            if let error = error { result = .failure(error) }
            else if let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
                    let data = data, let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any], json["error"] == nil {
                result = .success(json)
            } else {
                result = .failure(NSError(domain: "MusicAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "Music service could not load this page. Please retry."]))
            }
            DispatchQueue.main.async { completion(result) }
        }.resume()
    }

    func search(query: String, filter: SearchFilter = .all, completion: @escaping (Result<[Track], Error>) -> Void) {
        searchCatalog(query: query) { result in completion(result.map { $0.tracks }) }
    }

    func searchCatalog(query: String, completion: @escaping (Result<MusicSearchResults, Error>) -> Void) {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { DispatchQueue.main.async { completion(.success(MusicSearchResults())) }; return }
        request("search", body: ["query": query]) { result in
            completion(result.map { self.parseCatalog($0) })
        }
    }

    func fetchAlbum(_ album: Album, completion: @escaping (Result<Playlist, Error>) -> Void) {
        guard album.id.hasPrefix("MPRE") else {
            DispatchQueue.main.async { completion(.failure(NSError(domain: "MusicAPI", code: -2, userInfo: [NSLocalizedDescriptionKey: "Invalid album identifier."]))) }
            return
        }
        request("browse", body: ["browseId": album.id]) { result in
            completion(result.flatMap { json in
                let tracks = self.parseCatalog(json).tracks.map { track in
                    Track(id: track.id, title: track.title,
                          artist: track.artist == "Unknown Artist" ? album.artist : track.artist,
                          album: album.title, duration: track.duration,
                          artworkUrl: track.artworkUrl.isEmpty ? (album.thumbnailUrl ?? "") : track.artworkUrl)
                }
                guard !tracks.isEmpty else {
                    return .failure(NSError(domain: "MusicAPI", code: -3, userInfo: [NSLocalizedDescriptionKey: "No playable tracks were returned for this album. Please retry."]))
                }
                return .success(Playlist(id: album.id, title: album.title, author: album.artist, thumbnailUrl: album.thumbnailUrl, trackCount: tracks.count, tracks: tracks))
            })
        }
    }

    private func text(_ value: Any?) -> String {
        guard let value = value as? [String: Any] else { return "" }
        if let simple = value["simpleText"] as? String { return simple }
        return (value["runs"] as? [[String: Any]] ?? []).compactMap { $0["text"] as? String }.joined()
    }

    private func endpointID(_ object: [String: Any], kind: String) -> String? {
        for key in ["navigationEndpoint", "onTap", "playNavigationEndpoint"] {
            if let endpoint = object[key] as? [String: Any], let value = endpoint[kind] as? [String: Any],
               let id = value[kind == "watchEndpoint" ? "videoId" : "browseId"] as? String { return id }
        }
        return nil
    }

    private func parseCatalog(_ json: [String: Any]) -> MusicSearchResults {
        var result = MusicSearchResults()
        var seenTracks = Set<String>()
        var seenAlbums = Set<String>()
        func visit(_ value: Any) {
            if let items = value as? [Any] { items.forEach(visit); return }
            guard let object = value as? [String: Any] else { return }
            for key in ["musicResponsiveListItemRenderer", "musicCardShelfRenderer", "musicTwoRowItemRenderer"] {
                guard let item = object[key] as? [String: Any] else { continue }
                let columns = item["flexColumns"] as? [[String: Any]] ?? []
                let titleObject = (columns.first?["musicResponsiveListItemFlexColumnRenderer"] as? [String: Any])?["text"] as? [String: Any] ?? item["title"] as? [String: Any] ?? [:]
                let title = text(titleObject)
                let subtitleObject = columns.count > 1 ? (columns[1]["musicResponsiveListItemFlexColumnRenderer"] as? [String: Any])?["text"] : item["subtitle"]
                let runs = (subtitleObject as? [String: Any])?["runs"] as? [[String: Any]] ?? []
                let artistRun = runs.first { run in
                    guard let nav = run["navigationEndpoint"] as? [String: Any], let browse = nav["browseEndpoint"] as? [String: Any], let id = browse["browseId"] as? String else { return false }
                    return id.hasPrefix("UC")
                }
                let parts = text(subtitleObject).components(separatedBy: " • ")
                let artist = artistRun?["text"] as? String ?? parts.first(where: { !["Song", "Video", "Album", "Single", "EP"].contains($0) && !$0.contains(":") && !$0.contains("views") && !$0.isEmpty }) ?? "Unknown Artist"
                var thumbnail = ""
                func findThumbnail(_ value: Any) {
                    if let dict = value as? [String: Any] {
                        if let list = dict["thumbnails"] as? [[String: Any]], let url = list.last?["url"] as? String { thumbnail = url }
                        else { dict.values.forEach(findThumbnail) }
                    }
                }
                if let thumb = item["thumbnail"] { findThumbnail(thumb) }
                let titleRuns = titleObject["runs"] as? [[String: Any]] ?? []
                let browseID = endpointID(item, kind: "browseEndpoint") ?? titleRuns.compactMap { endpointID($0, kind: "browseEndpoint") }.first
                if let id = browseID, id.hasPrefix("MPRE"), !title.isEmpty, seenAlbums.insert(id).inserted {
                    result.albums.append(Album(id: id, title: title, artist: artist, thumbnailUrl: thumbnail))
                }
                var videoID = (item["playlistItemData"] as? [String: Any])?["videoId"] as? String ?? endpointID(item, kind: "watchEndpoint") ?? titleRuns.compactMap { endpointID($0, kind: "watchEndpoint") }.first
                if videoID == nil, let overlay = item["overlay"] as? [String: Any],
                   let renderer = overlay["musicItemThumbnailOverlayRenderer"] as? [String: Any],
                   let content = renderer["content"] as? [String: Any], let button = content["musicPlayButtonRenderer"] as? [String: Any] {
                    videoID = endpointID(button, kind: "watchEndpoint")
                }
                if let id = videoID, id.range(of: "^[A-Za-z0-9_-]{11}$", options: .regularExpression) != nil, !title.isEmpty, seenTracks.insert(id).inserted {
                    var duration: Double = 0
                    let fixed = item["fixedColumns"] as? [[String: Any]] ?? []
                    let timeText: String = fixed.compactMap { ($0["musicResponsiveListItemFixedColumnRenderer"] as? [String: Any])?["text"] }.map(text).first ?? parts.last ?? ""
                    let timeParts = timeText.components(separatedBy: ":").compactMap { Double($0) }
                    if timeParts.count >= 2 && timeParts.count <= 3 { duration = timeParts.reduce(0) { $0 * 60 + $1 } }
                    result.tracks.append(Track(id: id, title: title, artist: artist, duration: duration, artworkUrl: thumbnail))
                }
            }
            for key in object.keys.sorted() {
                if let child = object[key] { visit(child) }
            }
        }
        if let contents = json["contents"] { visit(contents) }
        return result
    }

    func fetchFeaturedPlaylists(completion: @escaping ([Playlist]) -> Void) {
        DispatchQueue.main.async { completion([]) }
    }

    func fetchTopCharts(completion: @escaping ([Track]) -> Void) {
        DispatchQueue.main.async { completion([]) }
    }
}
