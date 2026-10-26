import Foundation

final class StorageManager {

    static let shared = StorageManager()

    static let favoritesDidChange = Notification.Name("StorageManagerFavoritesDidChange")
    static let historyDidChange = Notification.Name("StorageManagerHistoryDidChange")
    static let playlistsDidChange = Notification.Name("StorageManagerPlaylistsDidChange")

    private let defaults = UserDefaults.standard
    private let lock = NSLock()
    private let favoritesKey = "iMusic_Favorites"
    private let historyKey = "iMusic_ListeningHistory"
    private let playlistsKey = "iMusic_UserPlaylists"

    private init() {}

    // MARK: - Favorites

    func getFavorites() -> [Track] {
        lock.lock()
        defer { lock.unlock() }
        guard let data = defaults.data(forKey: favoritesKey),
              let tracks = try? JSONDecoder().decode([Track].self, from: data) else {
            return []
        }
        return tracks
    }

    func isFavorite(trackId: String) -> Bool {
        return getFavorites().contains { $0.id == trackId }
    }

    func toggleFavorite(track: Track) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        var favorites: [Track] = []
        if let data = defaults.data(forKey: favoritesKey),
           let list = try? JSONDecoder().decode([Track].self, from: data) {
            favorites = list
        }
        var isNowFavorite = false

        if let idx = favorites.firstIndex(where: { $0.id == track.id }) {
            favorites.remove(at: idx)
            isNowFavorite = false
        } else {
            var newTrack = track
            newTrack.isFavorite = true
            favorites.insert(newTrack, at: 0)
            isNowFavorite = true
        }

        if let data = try? JSONEncoder().encode(favorites) {
            defaults.set(data, forKey: favoritesKey)
            NotificationCenter.default.post(name: StorageManager.favoritesDidChange, object: nil)
        }
        return isNowFavorite
    }

    // MARK: - Listening History

    func getHistory() -> [Track] {
        lock.lock()
        defer { lock.unlock() }
        guard let data = defaults.data(forKey: historyKey),
              let tracks = try? JSONDecoder().decode([Track].self, from: data) else {
            return []
        }
        return tracks
    }

    func recordHistory(track: Track) {
        lock.lock()
        defer { lock.unlock() }

        var history: [Track] = []
        if let data = defaults.data(forKey: historyKey),
           let list = try? JSONDecoder().decode([Track].self, from: data) {
            history = list
        }
        history.removeAll { $0.id == track.id }
        history.insert(track, at: 0)

        // Cap history at 100 tracks
        if history.count > 100 {
            history = Array(history.prefix(100))
        }

        if let data = try? JSONEncoder().encode(history) {
            defaults.set(data, forKey: historyKey)
            NotificationCenter.default.post(name: StorageManager.historyDidChange, object: nil)
        }
    }

    // MARK: - Playlists

    func getPlaylists() -> [Playlist] {
        lock.lock()
        defer { lock.unlock() }
        guard let data = defaults.data(forKey: playlistsKey),
              let list = try? JSONDecoder().decode([Playlist].self, from: data) else {
            return []
        }
        return list
    }

    func createPlaylist(title: String) -> Playlist {
        lock.lock()
        defer { lock.unlock() }

        var list: [Playlist] = []
        if let data = defaults.data(forKey: playlistsKey),
           let current = try? JSONDecoder().decode([Playlist].self, from: data) {
            list = current
        }
        let newPlaylist = Playlist(id: UUID().uuidString, title: title, author: "You", trackCount: 0, tracks: [])
        list.insert(newPlaylist, at: 0)
        if let data = try? JSONEncoder().encode(list) {
            defaults.set(data, forKey: playlistsKey)
            NotificationCenter.default.post(name: StorageManager.playlistsDidChange, object: nil)
        }
        return newPlaylist
    }

    func addTrack(_ track: Track, to playlistId: String) {
        lock.lock()
        defer { lock.unlock() }

        var list: [Playlist] = []
        if let data = defaults.data(forKey: playlistsKey),
           let current = try? JSONDecoder().decode([Playlist].self, from: data) {
            list = current
        }
        if let idx = list.firstIndex(where: { $0.id == playlistId }) {
            var playlist = list[idx]
            if !playlist.tracks.contains(where: { $0.id == track.id }) {
                playlist.tracks.append(track)
                list[idx] = Playlist(id: playlist.id,
                                     title: playlist.title,
                                     author: playlist.author,
                                     thumbnailUrl: playlist.tracks.first?.artworkUrl,
                                     trackCount: playlist.tracks.count,
                                     tracks: playlist.tracks)
                if let data = try? JSONEncoder().encode(list) {
                    defaults.set(data, forKey: playlistsKey)
                    NotificationCenter.default.post(name: StorageManager.playlistsDidChange, object: nil)
                }
            }
        }
    }

    func removeTrack(at index: Int, from playlistId: String) {
        lock.lock()
        defer { lock.unlock() }

        var list: [Playlist] = []
        if let data = defaults.data(forKey: playlistsKey),
           let current = try? JSONDecoder().decode([Playlist].self, from: data) {
            list = current
        }
        if let idx = list.firstIndex(where: { $0.id == playlistId }) {
            var playlist = list[idx]
            if index < playlist.tracks.count {
                playlist.tracks.remove(at: index)
                list[idx] = Playlist(id: playlist.id,
                                     title: playlist.title,
                                     author: playlist.author,
                                     thumbnailUrl: playlist.tracks.first?.artworkUrl,
                                     trackCount: playlist.tracks.count,
                                     tracks: playlist.tracks)
                if let data = try? JSONEncoder().encode(list) {
                    defaults.set(data, forKey: playlistsKey)
                    NotificationCenter.default.post(name: StorageManager.playlistsDidChange, object: nil)
                }
            }
        }
    }

    private func savePlaylists(_ list: [Playlist]) {
        if let data = try? JSONEncoder().encode(list) {
            defaults.set(data, forKey: playlistsKey)
            NotificationCenter.default.post(name: StorageManager.playlistsDidChange, object: nil)
        }
    }
}
