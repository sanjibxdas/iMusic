import Foundation

struct Track: Codable, Equatable, Hashable {
    let id: String
    let title: String
    let artist: String
    let album: String
    let duration: TimeInterval
    let artworkUrl: String
    var streamUrl: String?
    var isFavorite: Bool

    init(id: String,
         title: String,
         artist: String,
         album: String = "",
         duration: TimeInterval = 0,
         artworkUrl: String = "",
         streamUrl: String? = nil,
         isFavorite: Bool = false) {
        self.id = id
        self.title = title
        self.artist = artist
        self.album = album
        self.duration = duration
        self.artworkUrl = artworkUrl
        self.streamUrl = streamUrl
        self.isFavorite = isFavorite
    }

    var formattedDuration: String {
        guard duration > 0 else { return "--:--" }
        let totalSeconds = Int(duration)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    static func == (lhs: Track, rhs: Track) -> Bool {
        return lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
