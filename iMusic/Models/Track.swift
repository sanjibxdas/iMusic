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

    enum CodingKeys: String, CodingKey {
        case id, title, artist, album, duration, artworkUrl, streamUrl, isFavorite
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.title = (try? container.decode(String.self, forKey: .title)) ?? "Unknown Track"
        self.artist = (try? container.decode(String.self, forKey: .artist)) ?? "Unknown Artist"
        self.album = (try? container.decode(String.self, forKey: .album)) ?? ""
        self.duration = (try? container.decode(TimeInterval.self, forKey: .duration)) ?? 0
        self.artworkUrl = (try? container.decode(String.self, forKey: .artworkUrl)) ?? ""
        self.streamUrl = try? container.decodeIfPresent(String.self, forKey: .streamUrl)
        self.isFavorite = (try? container.decode(Bool.self, forKey: .isFavorite)) ?? false
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
