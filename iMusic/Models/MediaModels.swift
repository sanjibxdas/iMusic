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
}
