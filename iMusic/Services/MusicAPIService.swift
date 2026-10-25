import Foundation

enum SearchFilter: String, CaseIterable {
    case all = "All"
    case songs = "Songs"
    case albums = "Albums"
    case artists = "Artists"
    case playlists = "Playlists"
}

final class MusicAPIService {

    static let shared = MusicAPIService()

    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 25
        self.session = URLSession(configuration: config)
    }

    // MARK: - Search

    func search(query: String, filter: SearchFilter = .all, completion: @escaping (Result<[Track], Error>) -> Void) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            completion(.success([]))
            return
        }

        searchInnertube(query: trimmed) { [weak self] result in
            switch result {
            case .success(let tracks) where !tracks.isEmpty:
                completion(.success(tracks))
            case .success, .failure:
                // Fallback to iTunes Search API
                self?.searchITunes(query: trimmed, completion: completion)
            }
        }
    }

    // MARK: - Innertube Search

    private func searchInnertube(query: String, completion: @escaping (Result<[Track], Error>) -> Void) {
        guard let url = URL(string: "https://music.youtube.com/youtubei/v1/search") else {
            completion(.failure(NSError(domain: "MusicAPI", code: -1, userInfo: nil)))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")
        request.setValue("https://music.youtube.com", forHTTPHeaderField: "Origin")

        let payload: [String: Any] = [
            "context": [
                "client": [
                    "clientName": "WEB_REMIX",
                    "clientVersion": "1.20231215.01.00",
                    "gl": "US",
                    "hl": "en"
                ]
            ],
            "query": query
        ]

        guard let bodyData = try? JSONSerialization.data(withJSONObject: payload, options: []) else {
            completion(.failure(NSError(domain: "MusicAPI", code: -1, userInfo: nil)))
            return
        }
        request.httpBody = bodyData

        let task = session.dataTask(with: request) { data, _, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data,
                  let json = (try? JSONSerialization.jsonObject(with: data, options: [])) as? [String: Any] else {
                completion(.failure(NSError(domain: "MusicAPI", code: -2, userInfo: nil)))
                return
            }

            let tracks = self.parseInnertubeSearchResults(json: json)
            completion(.success(tracks))
        }
        task.resume()
    }

    private func parseInnertubeSearchResults(json: [String: Any]) -> [Track] {
        var tracks: [Track] = []
        var seenIds = Set<String>()

        guard let contents = json["contents"] as? [String: Any],
              let tabbed = contents["tabbedSearchResultsRenderer"] as? [String: Any],
              let tabs = tabbed["tabs"] as? [[String: Any]],
              let firstTab = tabs.first,
              let tabRenderer = firstTab["tabRenderer"] as? [String: Any],
              let content = tabRenderer["content"] as? [String: Any],
              let sectionList = content["sectionListRenderer"] as? [String: Any],
              let sectionContents = sectionList["contents"] as? [[String: Any]] else {
            return []
        }

        for section in sectionContents {
            // 1. Top Card: musicCardShelfRenderer (Exact Match top result)
            if let card = section["musicCardShelfRenderer"] as? [String: Any] {
                var videoId = ""
                if let onTab = card["onTap"] as? [String: Any],
                   let watchEndpoint = onTab["watchEndpoint"] as? [String: Any],
                   let id = watchEndpoint["videoId"] as? String {
                    videoId = id
                }

                var title = ""
                if let titleRuns = (card["title"] as? [String: Any])?["runs"] as? [[String: Any]],
                   let t = titleRuns.first?["text"] as? String {
                    title = t
                }

                var artist = "Unknown Artist"
                if let subtitleRuns = (card["subtitle"] as? [String: Any])?["runs"] as? [[String: Any]] {
                    let filtered = subtitleRuns.compactMap { $0["text"] as? String }.filter {
                        $0 != " • " && !$0.contains("views") && !$0.contains("Video") && !$0.contains(":")
                    }
                    if let first = filtered.first { artist = first }
                }

                var artworkUrl = ""
                if let thumbRenderer = (card["thumbnail"] as? [String: Any])?["musicThumbnailRenderer"] as? [String: Any],
                   let thumbObj = (thumbRenderer["thumbnail"] as? [String: Any])?["thumbnails"] as? [[String: Any]],
                   let lastThumb = thumbObj.last,
                   let url = lastThumb["url"] as? String {
                    artworkUrl = url
                }

                if !videoId.isEmpty && !title.isEmpty && !seenIds.contains(videoId) {
                    seenIds.insert(videoId)
                    tracks.append(Track(id: videoId, title: title, artist: artist, artworkUrl: artworkUrl))
                }
            }

            // 2. Sections: itemSectionRenderer (Primary list in modern Innertube)
            if let itemSec = section["itemSectionRenderer"] as? [String: Any],
               let subContents = itemSec["contents"] as? [[String: Any]] {
                for item in subContents {
                    if let track = parseResponsiveListItem(item) {
                        if !seenIds.contains(track.id) {
                            seenIds.insert(track.id)
                            tracks.append(track)
                        }
                    }
                }
            }

            // 3. Sections: musicShelfRenderer (Classic list fallback)
            if let shelf = section["musicShelfRenderer"] as? [String: Any],
               let shelfContents = shelf["contents"] as? [[String: Any]] {
                for item in shelfContents {
                    if let track = parseResponsiveListItem(item) {
                        if !seenIds.contains(track.id) {
                            seenIds.insert(track.id)
                            tracks.append(track)
                        }
                    }
                }
            }
        }

        return tracks
    }

    private func parseResponsiveListItem(_ item: [String: Any]) -> Track? {
        guard let listItem = item["musicResponsiveListItemRenderer"] as? [String: Any] else { return nil }

        // Video ID
        var videoId = ""
        if let playlistItemData = listItem["playlistItemData"] as? [String: Any],
           let id = playlistItemData["videoId"] as? String, !id.isEmpty {
            videoId = id
        }
        if videoId.isEmpty {
            if let overlay = listItem["overlay"] as? [String: Any],
               let content = (overlay["musicItemThumbnailOverlayRenderer"] as? [String: Any])?["content"] as? [String: Any],
               let playBtn = content["musicPlayButtonRenderer"] as? [String: Any],
               let nav = playBtn["playNavigationEndpoint"] as? [String: Any],
               let watch = nav["watchEndpoint"] as? [String: Any],
               let id = watch["videoId"] as? String {
                videoId = id
            }
        }

        guard !videoId.isEmpty else { return nil }
        guard let flexColumns = listItem["flexColumns"] as? [[String: Any]], !flexColumns.isEmpty else { return nil }

        // Column 0: Track Title
        var title = ""
        if let col0 = flexColumns[0]["musicResponsiveListItemFlexColumnRenderer"] as? [String: Any],
           let textObj = col0["text"] as? [String: Any],
           let runs = textObj["runs"] as? [[String: Any]],
           let firstRun = runs.first?["text"] as? String {
            title = firstRun
        }

        guard !title.isEmpty else { return nil }

        // Column 1: Artist, Album, Duration
        var artist = "Unknown Artist"
        var album = ""
        var durationSec: TimeInterval = 0

        if flexColumns.count > 1,
           let col1 = flexColumns[1]["musicResponsiveListItemFlexColumnRenderer"] as? [String: Any],
           let textObj = col1["text"] as? [String: Any],
           let runs = textObj["runs"] as? [[String: Any]] {
            let textRuns = runs.compactMap { $0["text"] as? String }.filter {
                $0 != " • " && $0 != "Song" && $0 != "Video" && !$0.contains("views")
            }
            if let first = textRuns.first { artist = first }
            if textRuns.count > 1 { album = textRuns[1] }
            if let last = textRuns.last, last.contains(":") {
                let parts = last.components(separatedBy: ":")
                if parts.count == 2, let m = Double(parts[0]), let s = Double(parts[1]) {
                    durationSec = (m * 60) + s
                }
            }
        }

        // Thumbnail
        var artworkUrl = ""
        if let thumbRenderer = (listItem["thumbnail"] as? [String: Any])?["musicThumbnailRenderer"] as? [String: Any],
           let thumbs = (thumbRenderer["thumbnail"] as? [String: Any])?["thumbnails"] as? [[String: Any]],
           let best = thumbs.last,
           let u = best["url"] as? String {
            artworkUrl = u
        }

        return Track(id: videoId, title: title, artist: artist, album: album, duration: durationSec, artworkUrl: artworkUrl)
    }

    // MARK: - iTunes Fallback Search

    private func searchITunes(query: String, completion: @escaping (Result<[Track], Error>) -> Void) {
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://itunes.apple.com/search?term=\(encoded)&entity=song&limit=25") else {
            completion(.failure(NSError(domain: "MusicAPI", code: -1, userInfo: nil)))
            return
        }

        let task = session.dataTask(with: url) { data, _, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let data = data,
                  let json = (try? JSONSerialization.jsonObject(with: data, options: [])) as? [String: Any],
                  let results = json["results"] as? [[String: Any]] else {
                completion(.failure(NSError(domain: "MusicAPI", code: -2, userInfo: nil)))
                return
            }

            var tracks: [Track] = []
            for item in results {
                let title = (item["trackName"] as? String) ?? "Unknown Track"
                let artist = (item["artistName"] as? String) ?? "Unknown Artist"
                let album = (item["collectionName"] as? String) ?? ""
                let millis = (item["trackTimeMillis"] as? Double) ?? 0
                let artwork100 = (item["artworkUrl100"] as? String) ?? ""
                let highResArtwork = artwork100.replacingOccurrences(of: "100x100bb", with: "600x600bb")
                let id = "itunes_\((item["trackId"] as? Int) ?? 0)"
                tracks.append(Track(id: id, title: title, artist: artist, album: album, duration: millis / 1000.0, artworkUrl: highResArtwork))
            }
            completion(.success(tracks))
        }
        task.resume()
    }

    // MARK: - Featured & Editorial Content

    func fetchFeaturedPlaylists(completion: @escaping ([Playlist]) -> Void) {
        let playlists = [
            Playlist(id: "RDCLAK5uy_kmPRjFGN7YstCHdnuf39_7t54v_mJ9Gw",
                     title: "Today's Hits",
                     author: "Apple Music",
                     thumbnailUrl: "https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=600&auto=format&fit=crop&q=80",
                     trackCount: 50),
            Playlist(id: "RDCLAK5uy_kL5fD_vKjS3WpCg3f8y9X0z1A2b3c4d5",
                     title: "A-List Pop",
                     author: "Apple Music Pop",
                     thumbnailUrl: "https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=600&auto=format&fit=crop&q=80",
                     trackCount: 45),
            Playlist(id: "RDCLAK5uy_l4s3t2u1v0w9x8y7z6a5b4c3d2e1f0g",
                     title: "Chill Lounge",
                     author: "Apple Music Chill",
                     thumbnailUrl: "https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=600&auto=format&fit=crop&q=80",
                     trackCount: 60),
            Playlist(id: "RDCLAK5uy_n9m8l7k6j5h4g3f2e1d0c9b8a7z6y5x",
                     title: "Rap Life",
                     author: "Apple Music Hip-Hop",
                     thumbnailUrl: "https://images.unsplash.com/photo-1508700115892-45ecd05ae2ad?w=600&auto=format&fit=crop&q=80",
                     trackCount: 40)
        ]
        completion(playlists)
    }

    func fetchTopCharts(completion: @escaping ([Track]) -> Void) {
        search(query: "Top Global Hits 2026") { result in
            switch result {
            case .success(let tracks):
                completion(tracks)
            case .failure:
                completion([])
            }
        }
    }
}
