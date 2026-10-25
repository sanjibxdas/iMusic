import Foundation

final class StorageManager {

    static let shared = StorageManager()

    static let favoritesDidChange = Notification.Name("StorageManagerFavoritesDidChange")
    static let historyDidChange = Notification.Name("StorageManagerHistoryDidChange")
    static let playlistsDidChange = Notification.Name("StorageManagerPlaylistsDidChange")

    private let defaults = UserDefaults.standard
    private let favoritesKey = "iMusic_Favorites"
    private let historyKey = "iMusic_ListeningHistory"
    private let playlistsKey = "iMusic_UserPlaylists"

    private init() {}

    // MARK: - Favorites

    func getFavorites() -> [Track] {
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
        var favorites = getFavorites()
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
        guard let data = defaults.data(forKey: historyKey),
              let tracks = try? JSONDecoder().decode([Track].self, from: data) else {
            return []
        }
        return tracks
    }

    func recordHistory(track: Track) {
        var history = getHistory()
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
        guard let data = defaults.data(forKey: playlistsKey),
              let list = try? JSONDecoder().decode([Playlist].self, from: data) else {
            return []
        }
        return list
    }

    func createPlaylist(title: String) -> Playlist {
        var list = getPlaylists()
        let newPlaylist = Playlist(id: UUID().uuidString, title: title, author: "You", trackCount: 0, tracks: [])
        list.insert(newPlaylist, at: 0)
        savePlaylists(list)
        return newPlaylist
    }

    func addTrack(_ track: Track, to playlistId: String) {
        var list = getPlaylists()
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
                savePlaylists(list)
            }
        }
    }

    func removeTrack(at index: Int, from playlistId: String) {
        var list = getPlaylists()
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
                savePlaylists(list)
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
