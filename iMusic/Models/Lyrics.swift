import Foundation

struct LyricLine: Codable, Equatable {
    let time: TimeInterval
    let text: String
}

struct LyricsDocument: Codable, Equatable {
    let lines: [LyricLine]
    let plainLyrics: String?

    var hasTiming: Bool {
        return !lines.isEmpty
    }

    func lineIndex(at time: TimeInterval) -> Int? {
        guard !lines.isEmpty else { return nil }

        var activeIndex: Int?
        for (idx, line) in lines.enumerated() {
            if time >= line.time {
                activeIndex = idx
            } else {
                break
            }
        }
        return activeIndex
    }

    static func parseLRC(_ lrc: String) -> [LyricLine] {
        var result: [LyricLine] = []
        let rawLines = lrc.components(separatedBy: .newlines)

        for raw in rawLines {
            let trimmed = raw.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("[") else { continue }

            // Extract timestamp: [mm:ss.xx] or [mm:ss]
            guard let closeBracketIndex = trimmed.firstIndex(of: "]") else { continue }
            let timeString = String(trimmed[trimmed.index(after: trimmed.startIndex)..<closeBracketIndex])
            let text = String(trimmed[trimmed.index(after: closeBracketIndex)...]).trimmingCharacters(in: .whitespaces)

            let timeParts = timeString.components(separatedBy: ":")
            if timeParts.count == 2,
               let minutes = Double(timeParts[0]),
               let seconds = Double(timeParts[1]) {
                let totalSeconds = (minutes * 60.0) + seconds
                result.append(LyricLine(time: totalSeconds, text: text))
            }
        }

        return result.sorted { $0.time < $1.time }
    }
}
