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
        let pattern = "\\[(\\d{1,2}):(\\d{2})(?:[.:](\\d{1,3}))?\\]"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return [] }
        let rawLines = lrc.components(separatedBy: .newlines)

        for raw in rawLines {
            let trimmed = raw.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("[") else { continue }
            let nsStr = trimmed as NSString
            let matches = regex.matches(in: trimmed, options: [], range: NSRange(location: 0, length: nsStr.length))
            guard !matches.isEmpty else { continue }

            let lastMatch = matches.last!
            let textIndex = lastMatch.range.location + lastMatch.range.length
            let text = nsStr.substring(from: textIndex).trimmingCharacters(in: .whitespaces)

            for match in matches {
                let minStr = nsStr.substring(with: match.range(at: 1))
                let secStr = nsStr.substring(with: match.range(at: 2))
                var ms: Double = 0
                if match.range(at: 3).location != NSNotFound {
                    let msRaw = nsStr.substring(with: match.range(at: 3))
                    let factor = (msRaw.count == 2) ? 100.0 : 1000.0
                    ms = (Double(msRaw) ?? 0) / factor
                }
                if let minutes = Double(minStr), let seconds = Double(secStr) {
                    let total = (minutes * 60.0) + seconds + ms
                    result.append(LyricLine(time: total, text: text))
                }
            }
        }

        return result.sorted { $0.time < $1.time }
    }
}
