import Foundation

struct Artist: Codable, Equatable {
    let id: String
    let name: String
    let thumbnailUrl: String?
    let subscribers: String?

    init(id: String, name: String, thumbnailUrl: String? = nil, subscribers: String? = nil) {
        self.id = id
        self.name = name
        self.thumbnailUrl = thumbnailUrl
        self.subscribers = subscribers
    }
}

struct Album: Codable, Equatable {
    let id: String
    let title: String
    let artist: String
    let thumbnailUrl: String?
    let year: String?
    let trackCount: Int

    init(id: String, title: String, artist: String, thumbnailUrl: String? = nil, year: String? = nil, trackCount: Int = 0) {
        self.id = id
        self.title = title
        self.artist = artist
        self.thumbnailUrl = thumbnailUrl
        self.year = year
        self.trackCount = trackCount
    }
}

struct Playlist: Codable, Equatable {
    let id: String
    let title: String
    let author: String?
    let thumbnailUrl: String?
    let trackCount: Int
    var tracks: [Track]

    init(id: String, title: String, author: String? = nil, thumbnailUrl: String? = nil, trackCount: Int = 0, tracks: [Track] = []) {
        self.id = id
        self.title = title
        self.author = author
        self.thumbnailUrl = thumbnailUrl
        self.trackCount = trackCount
        self.tracks = tracks
    }

    enum CodingKeys: String, CodingKey {
        case id, title, author, thumbnailUrl, trackCount, tracks
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? container.decode(String.self, forKey: .id)) ?? UUID().uuidString
        self.title = (try? container.decode(String.self, forKey: .title)) ?? "Untitled Playlist"
        self.author = try? container.decodeIfPresent(String.self, forKey: .author)
        self.thumbnailUrl = try? container.decodeIfPresent(String.self, forKey: .thumbnailUrl)
        self.tracks = (try? container.decode([Track].self, forKey: .tracks)) ?? []
        self.trackCount = (try? container.decode(Int.self, forKey: .trackCount)) ?? tracks.count
    }
}
