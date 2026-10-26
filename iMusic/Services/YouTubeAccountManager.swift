import Foundation
import CommonCrypto

struct YouTubeAccount: Codable, Equatable {
    let name: String
    let email: String
    let avatarUrl: String?
    let cookie: String
    let sapisid: String?
}

final class YouTubeAccountManager {

    static let shared = YouTubeAccountManager()
    static let accountDidChangeNotification = Notification.Name("YouTubeAccountDidChange")

    private let keyAccount = "iMusic_connectedYouTubeAccount"
    private let defaults = UserDefaults.standard

    private(set) var currentAccount: YouTubeAccount?

    private init() {
        if let data = defaults.data(forKey: keyAccount),
           let acc = try? JSONDecoder().decode(YouTubeAccount.self, from: data) {
            self.currentAccount = acc
        }
    }

    var isConnected: Bool {
        return currentAccount != nil
    }

    func saveAccount(name: String, email: String, cookie: String, sapisid: String? = nil, avatarUrl: String? = nil) {
        // Extract sapisid from cookie string if not provided explicitly
        var resolvedSapisid = sapisid
        if resolvedSapisid == nil || resolvedSapisid!.isEmpty {
            for part in cookie.components(separatedBy: ";") {
                let trimmed = part.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("SAPISID=") {
                    resolvedSapisid = String(trimmed.dropFirst("SAPISID=".count))
                    break
                }
            }
        }

        let acc = YouTubeAccount(name: name, email: email, avatarUrl: avatarUrl, cookie: cookie, sapisid: resolvedSapisid)
        self.currentAccount = acc
        if let data = try? JSONEncoder().encode(acc) {
            defaults.set(data, forKey: keyAccount)
        }
        NotificationCenter.default.post(name: YouTubeAccountManager.accountDidChangeNotification, object: nil)
        syncAccountData()
    }

    func signOut() {
        currentAccount = nil
        defaults.removeObject(forKey: keyAccount)
        NotificationCenter.default.post(name: YouTubeAccountManager.accountDidChangeNotification, object: nil)
    }

    func syncAccountData(completion: ((Bool) -> Void)? = nil) {
        guard let acc = currentAccount else {
            completion?(false)
            return
        }

        var request = URLRequest(url: URL(string: "https://music.youtube.com/youtubei/v1/browse")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(acc.cookie, forHTTPHeaderField: "Cookie")
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 12_5_8 like Mac OS X)", forHTTPHeaderField: "User-Agent")
        request.setValue("https://music.youtube.com", forHTTPHeaderField: "Origin")
        request.setValue("https://music.youtube.com", forHTTPHeaderField: "X-Origin")

        if let sapisid = acc.sapisid, !sapisid.isEmpty {
            request.setValue(generateSAPISIDHash(sapisid: sapisid), forHTTPHeaderField: "Authorization")
        }

        let payload: [String: Any] = [
            "context": [
                "client": [
                    "clientName": "WEB_REMIX",
                    "clientVersion": "1.20231215.01.00",
                    "gl": "US",
                    "hl": "en"
                ]
            ],
            "browseId": "FEmusic_liked_videos"
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: payload, options: [])

        let task = URLSession.shared.dataTask(with: request) { data, _, _ in
            guard let data = data,
                  let json = (try? JSONSerialization.jsonObject(with: data, options: [])) as? [String: Any] else {
                DispatchQueue.main.async { completion?(false) }
                return
            }

            let tracks = self.parseBrowsePlaylistTracks(json: json)
            for track in tracks {
                if !StorageManager.shared.isFavorite(trackId: track.id) {
                    _ = StorageManager.shared.toggleFavorite(track: track)
                }
            }

            DispatchQueue.main.async {
                completion?(true)
            }
        }
        task.resume()
    }

    private func generateSAPISIDHash(sapisid: String, origin: String = "https://music.youtube.com") -> String {
        let timestamp = Int(Date().timeIntervalSince1970)
        let input = "\(timestamp) \(sapisid) \(origin)"
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))
        if let data = input.data(using: .utf8) {
            data.withUnsafeBytes { rawBuffer in
                _ = CC_SHA1(rawBuffer.baseAddress, CC_LONG(data.count), &digest)
            }
        }
        let sha1Hex = digest.map { String(format: "%02x", $0) }.joined()
        return "SAPISIDHASH \(timestamp)_\(sha1Hex)"
    }

    private func parseBrowsePlaylistTracks(json: [String: Any]) -> [Track] {
        var result: [Track] = []
        guard let contents = json["contents"] as? [String: Any],
              let singleColumn = contents["singleColumnBrowseResultsRenderer"] as? [String: Any],
              let tabs = singleColumn["tabs"] as? [[String: Any]],
              let firstTab = tabs.first,
              let tabRenderer = firstTab["tabRenderer"] as? [String: Any],
              let tabContent = tabRenderer["content"] as? [String: Any],
              let sectionList = tabContent["sectionListRenderer"] as? [String: Any],
              let sectionContents = sectionList["contents"] as? [[String: Any]] else {
            return []
        }

        for sec in sectionContents {
            guard let shelf = sec["musicPlaylistShelfRenderer"] as? [String: Any],
                  let shelfContents = shelf["contents"] as? [[String: Any]] else { continue }

            for item in shelfContents {
                guard let listItem = item["musicResponsiveListItemRenderer"] as? [String: Any] else { continue }
                var videoId = ""
                if let data = listItem["playlistItemData"] as? [String: Any],
                   let id = data["videoId"] as? String {
                    videoId = id
                }

                guard let cols = listItem["flexColumns"] as? [[String: Any]], !cols.isEmpty else { continue }
                var title = ""
                if let textObj = (cols[0]["musicResponsiveListItemFlexColumnRenderer"] as? [String: Any])?["text"] as? [String: Any],
                   let runs = textObj["runs"] as? [[String: Any]],
                   let t = runs.first?["text"] as? String {
                    title = t
                }

                var artist = "Unknown Artist"
                if cols.count > 1,
                   let textObj = (cols[1]["musicResponsiveListItemFlexColumnRenderer"] as? [String: Any])?["text"] as? [String: Any],
                   let runs = textObj["runs"] as? [[String: Any]],
                   let a = runs.first?["text"] as? String {
                    artist = a
                }

                var thumb = ""
                if let thumbRenderer = (listItem["thumbnail"] as? [String: Any])?["musicThumbnailRenderer"] as? [String: Any],
                   let thumbs = (thumbRenderer["thumbnail"] as? [String: Any])?["thumbnails"] as? [[String: Any]],
                   let best = thumbs.last?["url"] as? String {
                    thumb = best
                }

                if !videoId.isEmpty && !title.isEmpty {
                    result.append(Track(id: videoId, title: title, artist: artist, artworkUrl: thumb, isFavorite: true))
                }
            }
        }
        return result
    }
}
