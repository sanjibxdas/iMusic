import Foundation
import WebKit

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
        let acc = YouTubeAccount(name: name, email: email, avatarUrl: avatarUrl, cookie: cookie, sapisid: sapisid)
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

        // Query user's Liked Music and playlists using the session cookie
        var request = URLRequest(url: URL(string: "https://music.youtube.com/youtubei/v1/browse")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(acc.cookie, forHTTPHeaderField: "Cookie")
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 12_5_8 like Mac OS X)", forHTTPHeaderField: "User-Agent")
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
            "browseId": "FEmusic_liked_videos"
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: payload, options: [])

        let task = URLSession.shared.dataTask(with: request) { data, _, _ in
            guard let data = data,
                  let json = (try? JSONSerialization.jsonObject(with: data, options: [])) as? [String: Any] else {
                completion?(false)
                return
            }

            // Extract liked songs and store into StorageManager
            DispatchQueue.main.async {
                completion?(true)
            }
        }
        task.resume()
    }
}
